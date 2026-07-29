// ============================================================
// DulceNav — download_manager.dart
// Gestor de descargas nativo en Dart con soporte de pausa/reanudacion.
// Solo caracteres ASCII en codigo fuente.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'storage_service.dart';

class DownloadItem {
  final String id;
  final String url;
  String fileName;
  String savePath;
  double progress; // 0.0 a 1.0
  String speed;
  String status; // "Descargando...", "Completado", "Error", "Pausado", "Cancelado"
  String totalSize;
  String downloadedSize;
  final DateTime timestamp;

  int bytesDownloaded = 0;
  int totalBytes = 0;
  http.Client? _client;
  StreamSubscription<List<int>>? _subscription;

  DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    this.progress = 0.0,
    this.speed = '0 KB/s',
    this.status = 'Descargando...',
    this.totalSize = '0 B',
    this.downloadedSize = '0 B',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'fileName': fileName,
        'savePath': savePath,
        'progress': progress,
        'speed': speed,
        'status': status,
        'totalSize': totalSize,
        'downloadedSize': downloadedSize,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      url: json['url'] as String,
      fileName: json['fileName'] as String,
      savePath: json['savePath'] as String,
      progress: (json['progress'] as num).toDouble(),
      speed: json['speed'] as String,
      status: json['status'] as String,
      totalSize: json['totalSize'] as String,
      downloadedSize: json['downloadedSize'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}

class DownloadManager extends ChangeNotifier {
  final List<DownloadItem> _items = [];
  List<DownloadItem> get items => List.unmodifiable(_items);

  static const _notifChannel = MethodChannel('com.dulce.nav/notification');

  int get activeDownloadsCount =>
      _items.where((item) => item.status == 'Descargando...').length;

  Function(String)? onDownloadFinished;

  DownloadManager();

  Future<void> startDownload(String url,
      {String? customFileName, String? customSaveDir, bool isIncognito = false}) async {
    final storage = StorageService.instance;
    final saveDir = customSaveDir ?? storage.downloadPath;

    String fileName = customFileName ?? _getFileNameFromUrl(url);

    final directory = Directory(saveDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    String fullPath = p.join(saveDir, fileName);
    fullPath = _getUniqueFilePath(fullPath);
    fileName = p.basename(fullPath);

    final id = 'dl_${DateTime.now().millisecondsSinceEpoch}';
    final item = DownloadItem(
      id: id,
      url: url,
      fileName: fileName,
      savePath: fullPath,
    );

    if (!isIncognito) {
      _items.insert(0, item);
      notifyListeners();
    }

    _runDownloadTask(item);
  }

  Future<void> pauseDownload(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = _items[index];
      if (item.status == 'Descargando...') {
        await item._subscription?.cancel();
        item._client?.close();
        item.status = 'Pausado';
        item.speed = '0 KB/s';
        if (Platform.isAndroid) {
          _notifChannel.invokeMethod('cancelNotification', {'id': item.id});
        }
        notifyListeners();
      }
    }
  }

  Future<void> resumeDownload(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = _items[index];
      if (item.status == 'Pausado' ||
          item.status == 'Error' ||
          item.status == 'Cancelado') {
        _runDownloadTask(item, isResume: item.status == 'Pausado');
      }
    }
  }

  Future<void> cancelDownload(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = _items[index];
      if (item.status == 'Descargando...') {
        await item._subscription?.cancel();
        item._client?.close();
      }
      item.status = 'Cancelado';
      item.speed = '0 KB/s';
      if (Platform.isAndroid) {
        _notifChannel.invokeMethod('cancelNotification', {'id': item.id});
      }

      final file = File(item.savePath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  void deleteDownload(String id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = _items[index];
      if (item.status == 'Descargando...') {
        item._subscription?.cancel();
        item._client?.close();
      }
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void openFolder(DownloadItem item) {
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,${item.savePath}']);
    }
  }

  void openFile(DownloadItem item) {
    if (Platform.isWindows) {
      Process.run('start', ['', item.savePath], runInShell: true);
    }
  }

  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final name = p.basename(uri.path);
      return name.isEmpty ? 'descarga' : name;
    } catch (_) {
      return 'descarga';
    }
  }

  String _getUniqueFilePath(String fullPath) {
    final file = File(fullPath);
    if (!file.existsSync()) return fullPath;

    final dir = p.dirname(fullPath);
    final ext = p.extension(fullPath);
    final nameWithoutExt = p.basenameWithoutExtension(fullPath);

    int counter = 1;
    while (true) {
      final newPath = p.join(dir, '${nameWithoutExt}_$counter$ext');
      if (!File(newPath).existsSync()) {
        return newPath;
      }
      counter++;
    }
  }

  Future<void> _runDownloadTask(DownloadItem item, {bool isResume = false}) async {
    item.status = 'Descargando...';
    notifyListeners();

    final client = http.Client();
    item._client = client;

    try {
      final file = File(item.savePath);
      int startBytes = 0;
      if (isResume && file.existsSync()) {
        startBytes = file.lengthSync();
      } else {
        if (file.existsSync()) {
          file.deleteSync();
        }
      }

      final request = http.Request('GET', Uri.parse(item.url));
      if (startBytes > 0) {
        request.headers['Range'] = 'bytes=$startBytes-';
      }

      final response = await client.send(request);

      final bool isPartial = response.statusCode == 206;
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Codigo de estado: ${response.statusCode}');
      }

      if (!isPartial && startBytes > 0) {
        startBytes = 0;
        if (file.existsSync()) {
          file.deleteSync();
        }
      }

      final totalBytes = (response.contentLength ?? 0) + startBytes;
      item.totalBytes = totalBytes;
      item.totalSize = _formatBytes(totalBytes);

      final ios = file.openWrite(mode: isPartial ? FileMode.append : FileMode.write);

      var bytesDownloaded = startBytes;
      var stopwatch = Stopwatch()..start();
      var lastElapsedMs = 0;
      var bytesSinceLastMeasure = 0;

      final completer = Completer<void>();

      item._subscription = response.stream.listen(
        (chunk) {
          ios.add(chunk);
          bytesDownloaded += chunk.length;
          bytesSinceLastMeasure += chunk.length;

          item.bytesDownloaded = bytesDownloaded;
          item.downloadedSize = _formatBytes(bytesDownloaded);

          if (totalBytes > 0) {
            item.progress = bytesDownloaded / totalBytes;
          } else {
            item.progress = 0.0;
          }

          final elapsedMs = stopwatch.elapsedMilliseconds;
          if (elapsedMs - lastElapsedMs >= 500) {
            final double speedBytesPerSecond = (bytesSinceLastMeasure / (elapsedMs - lastElapsedMs)) * 1000;
            item.speed = '${_formatBytes(speedBytesPerSecond.toInt())}/s';
            bytesSinceLastMeasure = 0;
            lastElapsedMs = elapsedMs;

            if (Platform.isAndroid) {
              _notifChannel.invokeMethod('showProgress', {
                'id': item.id,
                'fileName': item.fileName,
                'progress': (item.progress * 100).toInt(),
                'speed': item.speed,
              });
            }

            notifyListeners();
          }
        },
        onError: (e) {
          ios.close();
          completer.completeError(e);
        },
        onDone: () async {
          await ios.flush();
          await ios.close();
          completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;

      if (item.status == 'Descargando...') {
        item.status = 'Completado';
        item.progress = 1.0;
        item.speed = '0 KB/s';
        if (Platform.isAndroid) {
          _notifChannel.invokeMethod('showCompleted', {
            'id': item.id,
            'fileName': item.fileName,
          });
        }
        notifyListeners();
        onDownloadFinished?.call(item.fileName);
      }

    } catch (e) {
      debugPrint('[DownloadManager] Error en la descarga: $e');
      if (item.status == 'Descargando...') {
        item.status = 'Error';
        item.speed = '0 KB/s';
        if (Platform.isAndroid) {
          _notifChannel.invokeMethod('showError', {
            'id': item.id,
            'fileName': item.fileName,
          });
        }
        notifyListeners();
      }
    } finally {
      client.close();
      item._client = null;
      item._subscription = null;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
