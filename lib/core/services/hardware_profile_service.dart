// ============================================================
// DulceNav — hardware_profile_service.dart
// Detección automática de hardware y gestión de perfiles de rendimiento.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:system_info2/system_info2.dart';
import 'storage_service.dart';

enum PerformanceProfile {
  ahorroRecursos,
  equilibrado,
  rendimientoMaximo,
  privacidadMaxima,
}

class DeviceHardwareInfo {
  final String osName;
  final String cpuName;
  final int cpuCores;
  final double totalRamGb;
  final double freeStorageGb;
  final String screenResolution;

  const DeviceHardwareInfo({
    required this.osName,
    required this.cpuName,
    required this.cpuCores,
    required this.totalRamGb,
    required this.freeStorageGb,
    required this.screenResolution,
  });

  Map<String, dynamic> toJson() => {
        'osName': osName,
        'cpuName': cpuName,
        'cpuCores': cpuCores,
        'totalRamGb': totalRamGb,
        'freeStorageGb': freeStorageGb,
        'screenResolution': screenResolution,
      };
}

class HardwareProfileService extends ChangeNotifier {
  HardwareProfileService._();
  static final HardwareProfileService instance = HardwareProfileService._();

  DeviceHardwareInfo? _cachedInfo;
  DeviceHardwareInfo? get cachedInfo => _cachedInfo;

  bool _isDetecting = false;
  bool get isDetecting => _isDetecting;

  /// Detecta de forma segura el hardware del equipo.
  Future<DeviceHardwareInfo> detect({BuildContext? context}) async {
    if (_cachedInfo != null) return _cachedInfo!;
    _isDetecting = true;
    notifyListeners();

    String osName = 'Desconocido';
    String cpuName = 'Procesador Genérico';
    int cpuCores = Platform.numberOfProcessors;
    double totalRamGb = 4.0;
    double freeStorageGb = 50.0;
    String screenResolution = '1920x1080';

    try {
      // 1. Obtener OS info
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        osName = 'Windows ${winInfo.productName} (${winInfo.numberOfCores} Cores)';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        osName = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
      } else {
        osName = Platform.operatingSystem;
      }
    } catch (e) {
      debugPrint('[HardwareProfileService] Error al obtener info del dispositivo: $e');
    }

    try {
      // 2. Obtener RAM y procesador vía system_info2
      totalRamGb = SysInfo.getTotalPhysicalMemory() / (1024 * 1024 * 1024);
      
      final cores = SysInfo.cores;
      cpuCores = cores.length;
      if (cores.isNotEmpty) {
        cpuName = cores.first.name.trim();
        if (cpuName.isEmpty) {
          cpuName = cores.first.vendor.trim();
        }
      }
      if (cpuName.isEmpty || cpuName == 'Procesador Genérico') {
        cpuName = Platform.isWindows ? 'Intel/AMD Processor' : 'ARM Octa-Core';
      }
    } catch (e) {
      debugPrint('[HardwareProfileService] Error al obtener info física: $e');
      // Fallbacks razonables
      totalRamGb = 4.0;
      cpuCores = Platform.numberOfProcessors;
      cpuName = Platform.isWindows ? 'Intel/AMD Processor' : 'ARM Octa-Core';
    }

    try {
      // 3. Resolución de pantalla
      if (context != null) {
        final mediaQuery = MediaQuery.maybeOf(context);
        if (mediaQuery != null) {
          final size = mediaQuery.size * mediaQuery.devicePixelRatio;
          screenResolution = '${size.width.round()}x${size.height.round()}';
        }
      }
    } catch (_) {}

    try {
      // 4. Espacio libre en disco (estimación o comando rápido en Windows)
      if (Platform.isWindows) {
        // En Windows, podemos usar un comando rápido de system
        final result = await Process.run('powershell', [
          '-Command',
          '(Get-Volume -DriveLetter C).SizeRemaining / 1GB'
        ]);
        if (result.exitCode == 0) {
          final val = double.tryParse(result.stdout.toString().trim());
          if (val != null) {
            freeStorageGb = val;
          }
        }
      }
    } catch (_) {}

    _cachedInfo = DeviceHardwareInfo(
      osName: osName,
      cpuName: cpuName,
      cpuCores: cpuCores,
      totalRamGb: totalRamGb,
      freeStorageGb: freeStorageGb,
      screenResolution: screenResolution,
    );

    _isDetecting = false;
    notifyListeners();
    return _cachedInfo!;
  }

  /// Recomienda el perfil de rendimiento ideal según las características del hardware detectado.
  PerformanceProfile recommendProfile(DeviceHardwareInfo info) {
    if (info.totalRamGb < 4.0) {
      return PerformanceProfile.ahorroRecursos;
    } else if (info.totalRamGb <= 8.0) {
      return PerformanceProfile.equilibrado;
    } else {
      // RAM > 8GB
      if (info.cpuCores >= 8) {
        return PerformanceProfile.rendimientoMaximo;
      } else {
        return PerformanceProfile.equilibrado;
      }
    }
  }

  /// Devuelve una explicación amigable sobre la recomendación basada en el hardware.
  String explainRecommendation(PerformanceProfile profile, DeviceHardwareInfo info) {
    final ramFormatted = info.totalRamGb.toStringAsFixed(1);
    switch (profile) {
      case PerformanceProfile.ahorroRecursos:
        return 'Recomendamos Ahorro de Recursos porque tu equipo cuenta con $ramFormatted GB de RAM. Este perfil optimiza al maximo el uso de memoria suspendiendo pestañas rapido.';
      case PerformanceProfile.equilibrado:
        return 'Recomendamos Equilibrado porque cuentas con $ramFormatted GB de RAM y un procesador de ${info.cpuCores} nucleos. Mantiene buena fluidez y un consumo de recursos moderado.';
      case PerformanceProfile.rendimientoMaximo:
        return 'Recomendamos Rendimiento Maximo porque tu equipo es muy potente (${ramFormatted} GB de RAM y ${info.cpuCores} nucleos). Habilita todos los efectos visuales y mantiene mas pestañas activas.';
      case PerformanceProfile.privacidadMaxima:
        return 'Recomendamos Privacidad Maxima si buscas proteccion total contra rastreadores y borrado de cookies automatico en cada sesion.';
    }
  }

  /// Aplica los ajustes específicos de cada perfil a la configuración global de StorageService.
  Future<void> applyProfile(PerformanceProfile profile, {bool overwrite = false}) async {
    final storage = StorageService.instance;

    // Si ya hay ajustes modificados y no nos permiten sobrescribir, no hacemos nada
    if (storage.performanceSettingsModified && !overwrite) {
      return;
    }

    switch (profile) {
      case PerformanceProfile.ahorroRecursos:
        await storage.setTabHibernateEnabled(true);
        await storage.setTabHibernateMinutes(5);
        await storage.setAdBlockEnabled(true);
        await storage.setTrackingProtection(true);
        await storage.setAntiPhishing(true);
        await storage.setAdaptiveThemeEnabled(false);
        await storage.setBlurIntensity('none');
        await storage.setSecureDnsMode('off');
        await storage.setClearOnClose(false);
        await storage.setSiteIsolation(false);
        break;

      case PerformanceProfile.equilibrado:
        await storage.setTabHibernateEnabled(true);
        await storage.setTabHibernateMinutes(15);
        await storage.setAdBlockEnabled(true);
        await storage.setTrackingProtection(true);
        await storage.setAntiPhishing(true);
        await storage.setAdaptiveThemeEnabled(true);
        await storage.setBlurIntensity('medium');
        await storage.setSecureDnsMode('cloudflare');
        await storage.setClearOnClose(false);
        await storage.setSiteIsolation(false);
        break;

      case PerformanceProfile.rendimientoMaximo:
        await storage.setTabHibernateEnabled(true);
        await storage.setTabHibernateMinutes(30);
        await storage.setAdBlockEnabled(true);
        await storage.setTrackingProtection(true);
        await storage.setAntiPhishing(true);
        await storage.setAdaptiveThemeEnabled(true);
        await storage.setBlurIntensity('high');
        await storage.setSecureDnsMode('cloudflare');
        await storage.setClearOnClose(false);
        await storage.setSiteIsolation(true);
        break;

      case PerformanceProfile.privacidadMaxima:
        await storage.setTabHibernateEnabled(true);
        await storage.setTabHibernateMinutes(15);
        await storage.setAdBlockEnabled(true);
        await storage.setTrackingProtection(true);
        await storage.setAntiPhishing(true);
        await storage.setAdaptiveThemeEnabled(true);
        await storage.setBlurIntensity('medium');
        await storage.setSecureDnsMode('quad9');
        await storage.setClearOnClose(true);
        await storage.setSiteIsolation(true);
        break;
    }

    // Al aplicar un perfil directamente, limpiamos la marca de "modificado manualmente"
    // ya que ahora coincide exactamente con el perfil seleccionado.
    await storage.setPerformanceProfile(profile.name);
    await storage.setPerformanceSettingsModified(false);
    notifyListeners();
  }
}
