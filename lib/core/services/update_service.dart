// ==============================================================
// DulceNav - update_service.dart
// Servicio reactivo de actualizaciones automaticas.
// Permite verificar versiones, descargar en segundo plano
// y ejecutar el instalador nativo en Windows.
// ==============================================================

import 'dart:convert';
import 'dart:io' show Platform, File, Process, exit;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'download_manager.dart';

enum UpdateState {
  idle,
  checking,
  noUpdate,
  updateAvailable,
  downloading,
  downloaded,
  error,
}

class UpdateService extends ChangeNotifier {
  static const String currentVersion = '1.8.0';
  static const String updateUrl = 'https://raw.githubusercontent.com/dulceuniverse/dulcenav-updates/main/version.json';

  UpdateState _state = UpdateState.idle;
  String _latestVersion = '';
  String _downloadUrl = '';
  String _notes = '';
  double _progress = 0.0;
  String? _localFilePath;
  String? _errorMessage;

  UpdateState get state => _state;
  String get latestVersion => _latestVersion;
  String get downloadUrl => _downloadUrl;
  String get notes => _notes;
  double get progress => _progress;
  String? get localFilePath => _localFilePath;
  String? get errorMessage => _errorMessage;

  // Verifica si hay actualizaciones disponibles
  Future<void> checkForUpdates({bool manual = false}) async {
    _state = UpdateState.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latest = data['version'] as String;
        final download = data['url'] as String;
        final notesText = data['notes'] as String;

        if (_isNewerVersion(latest, currentVersion)) {
          _latestVersion = latest;
          _downloadUrl = download;
          _notes = notesText;
          _state = UpdateState.updateAvailable;
        } else {
          _state = UpdateState.noUpdate;
        }
      } else {
        _useSimulatedUpdate(manual);
      }
    } catch (_) {
      _useSimulatedUpdate(manual);
    }

    notifyListeners();
  }

  // Compara semanticamente dos cadenas de version (ej: 1.4.0 > 1.3.9)
  bool _isNewerVersion(String latest, String current) {
    try {
      final latestClean = latest.split('+')[0].replaceAll('v', '').trim();
      final currentClean = current.split('+')[0].replaceAll('v', '').trim();

      final latestParts = latestClean.split('.').map(int.parse).toList();
      final currentParts = currentClean.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (_) {
      return latest.isNotEmpty && latest != current;
    }
  }

  // Fallback de simulacion para desarrollo y pruebas locales
  void _useSimulatedUpdate(bool manual) {
    _latestVersion = currentVersion;
    _downloadUrl = '';
    _notes = '';
    _state = UpdateState.noUpdate;
  }

  // Inicia la descarga del instalador a traves del DownloadManager
  void startDownloadUpdate(DownloadManager downloadManager) {
    if (_state != UpdateState.updateAvailable && _state != UpdateState.error) return;

    _state = UpdateState.downloading;
    _progress = 0.0;
    _errorMessage = null;
    notifyListeners();

    // Descargar en segundo plano
    downloadManager.startDownload(_downloadUrl, customFileName: 'DulceNav_Installer.exe');

    // Listener reactivo
    void progressListener() {
      final item = downloadManager.items.firstWhere(
        (i) => i.url == _downloadUrl,
        orElse: () => DownloadItem(id: '', url: '', fileName: '', savePath: ''),
      );

      if (item.id.isNotEmpty) {
        _progress = item.progress;
        if (item.status == 'Completado') {
          _state = UpdateState.downloaded;
          _localFilePath = item.savePath;
          downloadManager.removeListener(progressListener);
        } else if (item.status == 'Error' || item.status == 'Cancelado') {
          _state = UpdateState.error;
          _errorMessage = 'La descarga del instalador fallo o fue cancelada.';
          downloadManager.removeListener(progressListener);
        }
        notifyListeners();
      }
    }

    downloadManager.addListener(progressListener);
  }

  // Cierra el navegador y ejecuta el instalador nativo en Windows
  Future<void> installAndRestart() async {
    if (_localFilePath == null || _localFilePath!.isEmpty) return;

    final file = File(_localFilePath!);
    if (await file.exists()) {
      if (Platform.isWindows) {
        try {
          await Process.start(_localFilePath!, [], runInShell: true);
          exit(0);
        } catch (_) {
          await Process.run('start', ['', _localFilePath!], runInShell: true);
          exit(0);
        }
      }
    }
  }
}
