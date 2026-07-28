// ============================================================
// DulceNav - performance_service.dart
// Servidor de control de rendimiento y modo juego.
// Detecta procesos en ejecucion de forma automatica y aplica
// limites de consumo de recursos.
// ============================================================

import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class PerformanceService extends ChangeNotifier {
  PerformanceService._() {
    _init();
  }
  static final PerformanceService instance = PerformanceService._();

  bool _isGameModeActive = false;
  bool get isGameModeActive => _isGameModeActive;

  bool _manuallyActivated = false;
  bool get manuallyActivated => _manuallyActivated;

  bool _autoDetectEnabled = true;
  bool get autoDetectEnabled => _autoDetectEnabled;

  Timer? _detectionTimer;

  // Callback to set WebView FPS limit externally
  Future<void> Function(int fps)? onFpsLimitChanged;

  // Lista de ejecutables de juegos y launchers comunes en Windows
  static const List<String> _gameProcesses = [
    'valorant.exe',
    'leagueoflegends.exe',
    'csgo.exe',
    'cs2.exe',
    'gta5.exe',
    'minecraft.exe',
    'fortniteclient-win64-shipping.exe',
    'overwatch.exe',
    'fifa.exe',
    'cyberpunk2077.exe',
    'steam.exe',
    'epicgameslauncher.exe',
  ];

  void _init() {
    _isGameModeActive = StorageService.instance.gameModeEnabled;
    // Si inicia guardado de sesion anterior, asumimos activacion manual
    _manuallyActivated = _isGameModeActive;
    if (_autoDetectEnabled) {
      _startDetectionTimer();
    }
  }

  void setGameMode(bool active, {bool manual = false}) {
    if (manual) {
      _manuallyActivated = active;
    }
    if (_isGameModeActive != active) {
      _isGameModeActive = active;
      StorageService.instance.setGameModeEnabled(active);
      notifyListeners();
      _applyPerformanceSettings();
    }
  }

  void setAutoDetect(bool enabled) {
    if (_autoDetectEnabled != enabled) {
      _autoDetectEnabled = enabled;
      if (enabled) {
        _startDetectionTimer();
      } else {
        _detectionTimer?.cancel();
      }
      notifyListeners();
    }
  }

  void _startDetectionTimer() {
    _detectionTimer?.cancel();
    // Escaneo periodico cada 20 segundos
    _detectionTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkRunningGames();
    });
  }

  Future<void> _checkRunningGames() async {
    if (!_autoDetectEnabled || !Platform.isWindows) return;
    try {
      final result = await Process.run('tasklist', ['/NH', '/FO', 'CSV']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        bool gameDetected = false;
        for (final game in _gameProcesses) {
          if (output.contains(game)) {
            gameDetected = true;
            break;
          }
        }
        if (gameDetected && !_isGameModeActive) {
          debugPrint('[PerformanceService] Juego detectado en ejecucion. Activando Modo Juego.');
          setGameMode(true);
        } else if (!gameDetected && _isGameModeActive && !_manuallyActivated) {
          debugPrint('[PerformanceService] Ningun juego en ejecucion detectado. Desactivando Modo Juego.');
          setGameMode(false);
        }
      }
    } catch (e) {
      debugPrint('[PerformanceService] Error al verificar procesos en ejecucion: $e');
    }
  }

  void _applyPerformanceSettings() {
    if (_isGameModeActive) {
      // Limitar FPS del WebView a 30 fps (fluido pero reduce recursos)
      onFpsLimitChanged?.call(30);
    } else {
      // Quitar limites de FPS (0 = ilimitado)
      onFpsLimitChanged?.call(0);
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    super.dispose();
  }
}
