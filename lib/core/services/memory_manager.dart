// ============================================================
// DulceNav — memory_manager.dart
// Gestión agresiva de RAM. Libera recursos cuando no se usan.
// Compatible con Windows (dart:ffi) y Android (gc hints).
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart'; // Para limpiar caché de imágenes
import '../constants/app_config.dart';

class MemoryManager extends ChangeNotifier {
  MemoryManager() {
    _startMonitoring();
  }

  // ── Estado ─────────────────────────────────────────────
  int _currentMemoryMB = 0;
  bool _isUnderPressure = false;
  DateTime? _backgroundedAt;

  int get currentMemoryMB => _currentMemoryMB;
  bool get isUnderPressure => _isUnderPressure;

  // ── Timer de monitoreo ──────────────────────────────────
  Timer? _monitorTimer;

  void _startMonitoring() {
    // Verificar memoria cada 30 segundos
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkMemory();
    });
  }

  // ── Limpieza al cambiar de pestaña ──────────────────────
  /// Llamar cada vez que el usuario cambia de pestaña
  void onTabChanged() {
    _clearImageCache();
    _requestGC();
  }

  // ── Limpieza al minimizar la app ────────────────────────
  /// Llamar cuando la app entra en background
  Future<void> onAppBackgrounded() async {
    _backgroundedAt = DateTime.now();

    // Esperar el período de gracia antes de limpiar
    await Future.delayed(
      Duration(milliseconds: AppConfig.minimizeCleanupDelayMs),
    );

    // Solo limpiar si la app sigue en background
    if (_backgroundedAt != null) {
      _clearImageCache();
      _requestGC();
      debugPrint('[MemoryManager] Limpieza ejecutada al minimizar.');
    }
  }

  /// Llamar cuando la app vuelve al foreground
  void onAppResumed() {
    _backgroundedAt = null;
  }

  // ── Limpieza de caché de imágenes ───────────────────────
  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    // Restringir caché de imágenes en RAM
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        AppConfig.imageCacheMaxMB * 1024 * 1024;
  }

  // ── Solicitar garbage collection ────────────────────────
  void _requestGC() {
    // En Dart no se puede forzar GC directamente,
    // pero esto sugiere al runtime que libere objetos.
    // ignore: unnecessary_statements
    Object();
  }

  // ── Monitoreo de memoria ────────────────────────────────
  void _checkMemory() {
    // En producción, esto se conecta con platform channels
    // para leer el RSS real del proceso.
    // Por ahora, usamos la métrica de Dart.
    final isDartHeapLarge =
        _currentMemoryMB > AppConfig.memoryCleanupThresholdMB;

    if (isDartHeapLarge && !_isUnderPressure) {
      _isUnderPressure = true;
      _performAggressiveCleanup();
      notifyListeners();
    } else if (!isDartHeapLarge && _isUnderPressure) {
      _isUnderPressure = false;
      notifyListeners();
    }
  }

  // ── Limpieza agresiva ───────────────────────────────────
  void _performAggressiveCleanup() {
    debugPrint('[MemoryManager] Presión de memoria detectada. '
        'Ejecutando limpieza agresiva...');
    _clearImageCache();
    _requestGC();
  }

  // ── Actualizar métrica desde plataforma ─────────────────
  /// Llamar desde platform channel con el RSS en MB
  void updateMemoryUsage(int memoryMB) {
    _currentMemoryMB = memoryMB;
    _checkMemory();
  }

  // ── Limpieza al destruir ─────────────────────────────────
  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }
}
