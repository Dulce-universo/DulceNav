// ==============================================================
// DulceNav - dulce_sync_service.dart
// Servicio de sincronización segura (AES-256) multiplataforma.
// Importación/Exportación de archivos y sincronización LAN directa.
// ==============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

import 'storage_service.dart';
import 'password_service.dart';
import '../repositories/sync_repository.dart';

class LocalSyncProvider implements SyncRepository {
  @override
  Future<List<String>> fetchBookmarks() async {
    return StorageService.instance.bookmarks;
  }

  @override
  Future<void> uploadBookmarks(List<String> bookmarks) async {
    final storage = StorageService.instance;
    for (final item in bookmarks) {
      try {
        final Map<String, dynamic> bMap = jsonDecode(item);
        final title = bMap['title'] ?? '';
        final url = bMap['url'] ?? '';
        final timeStr = bMap['last_modified']?.toString();
        final lastModified = timeStr != null ? int.tryParse(timeStr) : null;
        if (url.isNotEmpty) {
          await storage.addBookmarkWithTitle(title, url, lastModified: lastModified);
        }
      } catch (_) {}
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPasswords() async {
    final pwdService = PasswordService.instance;
    await pwdService.loadCredentials();
    return pwdService.entries.map((entry) => {
      'domain': entry.domain,
      'username': entry.username,
      'password': entry.password,
      'last_modified': entry.lastModified,
    }).toList();
  }

  @override
  Future<void> uploadPasswords(List<Map<String, dynamic>> passwords) async {
    final pwdService = PasswordService.instance;
    for (final entry in passwords) {
      final domain = entry['domain'] ?? '';
      final username = entry['username'] ?? '';
      final password = entry['password'] ?? '';
      final lastModified = entry['last_modified'] as int?;
      if (domain.isNotEmpty && username.isNotEmpty && password.isNotEmpty) {
        await pwdService.saveCredentials(domain, username, password, lastModified: lastModified);
      }
    }
  }

  @override
  Future<Map<String, dynamic>> fetchSettings() async {
    final storage = StorageService.instance;
    return {
      'ad_block_enabled': storage.adBlockEnabled,
      'tracking_protection': storage.trackingProtectionEnabled,
      'anti_phishing': storage.antiPhishingEnabled,
      'ai_enabled': storage.aiEnabled,
      'search_engine': storage.searchEngine,
      'show_bookmarks_bar': storage.showBookmarksBar,
      'game_mode_enabled': storage.gameModeEnabled,
      'theme_preset': storage.themePreset,
      'last_modified': storage.settingsLastModified,
    };
  }

  @override
  Future<void> uploadSettings(Map<String, dynamic> settings) async {
    final storage = StorageService.instance;
    final int incomingTime = settings['last_modified'] as int? ?? 0;
    final int localTime = storage.settingsLastModified;

    if (incomingTime <= localTime && localTime > 0) {
      debugPrint('[LocalSyncProvider] Ajustes locales mas recientes o iguales. Omitiendo importacion.');
      return;
    }

    if (settings.containsKey('ad_block_enabled')) {
      await storage.setAdBlockEnabled(settings['ad_block_enabled']);
    }
    if (settings.containsKey('tracking_protection')) {
      await storage.setTrackingProtection(settings['tracking_protection']);
    }
    if (settings.containsKey('anti_phishing')) {
      await storage.setAntiPhishing(settings['anti_phishing']);
    }
    if (settings.containsKey('ai_enabled')) {
      await storage.setAiEnabled(settings['ai_enabled']);
    }
    if (settings.containsKey('search_engine')) {
      await storage.setSearchEngine(settings['search_engine']);
    }
    if (settings.containsKey('show_bookmarks_bar')) {
      await storage.setShowBookmarksBar(settings['show_bookmarks_bar']);
    }
    if (settings.containsKey('game_mode_enabled')) {
      await storage.setGameModeEnabled(settings['game_mode_enabled']);
    }
    if (settings.containsKey('theme_preset')) {
      await storage.setThemePreset(settings['theme_preset']);
    }
    await storage.setSettingsLastModified(incomingTime);
  }

  @override
  Future<int> getLastSyncTimestamp() async {
    return StorageService.instance.settingsLastModified;
  }
}

class DulceSyncService extends ChangeNotifier {
  DulceSyncService._();
  static final DulceSyncService instance = DulceSyncService._();

  SyncRepository _syncRepository = LocalSyncProvider();
  SyncRepository get syncRepository => _syncRepository;

  void setSyncRepository(SyncRepository repo) {
    _syncRepository = repo;
    notifyListeners();
  }

  // Estado del servidor LAN
  ServerSocket? _tcpServer;
  RawDatagramSocket? _udpSocket;
  bool _isServerRunning = false;
  bool get isServerRunning => _isServerRunning;

  // ── 1. Exportación / Importación (AES-256) ───────────────────

  // Cifrar datos del navegador a cadena Base64
  Future<String?> exportData(String passphrase) async {
    try {
      if (passphrase.isEmpty) return null;

      // 1. Obtener datos locales a traves del repositorio
      final bookmarks = await _syncRepository.fetchBookmarks();
      final passwords = await _syncRepository.fetchPasswords();
      final settings = await _syncRepository.fetchSettings();
      final history = StorageService.instance.history;

      final payload = {
        'version': '1.6.1',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'bookmarks': bookmarks,
        'history': history,
        'passwords': passwords,
        'settings': settings,
      };

      final plainJson = jsonEncode(payload);

      // Calcular checksum SHA-256 para integridad
      final checksum = sha256.convert(utf8.encode(plainJson)).toString();

      // Envolver los datos con su respectivo checksum
      final wrapper = {
        'checksum': checksum,
        'data': plainJson,
      };

      final wrappedJson = jsonEncode(wrapper);

      // 2. Cifrado simétrico AES-256
      final keyBytes = sha256.convert(utf8.encode(passphrase)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV.fromSecureRandom(16);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(wrappedJson, iv: iv);

      // Retornar en formato IV_Base64:Ciphertext_Base64
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('[DulceSyncService] Error al exportar datos: $e');
      return null;
    }
  }

  // Descifrar y combinar datos en el navegador
  Future<bool> importData(String passphrase, String encryptedPayload) async {
    try {
      if (passphrase.isEmpty || encryptedPayload.isEmpty) return false;

      final parts = encryptedPayload.split(':');
      if (parts.length != 2) return false;

      final ivBase64 = parts[0];
      final cipherBase64 = parts[1];

      final keyBytes = sha256.convert(utf8.encode(passphrase)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV.fromBase64(ivBase64);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(cipherBase64), iv: iv);

      final Map<String, dynamic> wrapper = jsonDecode(decrypted);

      // Validacion de integridad mediante el checksum SHA-256
      final String? checksum = wrapper['checksum'] as String?;
      final String? dataJson = wrapper['data'] as String?;

      if (checksum == null || dataJson == null) {
        debugPrint('[DulceSyncService] Paquete de sincronizacion corrupto o con formato invalido.');
        return false;
      }

      final calculatedChecksum = sha256.convert(utf8.encode(dataJson)).toString();
      if (calculatedChecksum != checksum) {
        debugPrint('[DulceSyncService] Error de integridad SHA-256. La frase de seguridad puede ser incorrecta.');
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(dataJson);

      // 3. Procesar e importar datos
      final List<dynamic> importedBookmarks = data['bookmarks'] ?? [];
      final List<String> bookmarksList = importedBookmarks.map((e) => e.toString()).toList();
      await _syncRepository.uploadBookmarks(bookmarksList);

      // Importar historial (sigue siendo directo en StorageService por simplicidad)
      final storage = StorageService.instance;
      final List<dynamic> importedHistory = data['history'] ?? [];
      for (final item in importedHistory) {
        try {
          final Map<String, dynamic> hMap = jsonDecode(item);
          final title = hMap['title'] ?? '';
          final url = hMap['url'] ?? '';
          if (url.isNotEmpty) {
            await storage.addToHistoryWithTitle(title, url);
          }
        } catch (_) {}
      }

      // Importar contraseñas
      final List<dynamic> importedPasswords = data['passwords'] ?? [];
      final List<Map<String, dynamic>> passwordsList = importedPasswords
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await _syncRepository.uploadPasswords(passwordsList);

      // Importar ajustes
      final Map<String, dynamic> settings = Map<String, dynamic>.from(data['settings'] ?? {});
      await _syncRepository.uploadSettings(settings);

      debugPrint('[DulceSyncService] Importacion de datos completada exitosamente.');
      return true;
    } catch (e) {
      debugPrint('[DulceSyncService] Error al importar datos (¿Frase incorrecta?): $e');
      return false;
    }
  }

  // ── 2. Servidor Sincronización en Red Local (LAN) ────────────

  // Iniciar servidor local
  Future<void> startLanServer(
    String passphrase, {
    required Function(String status) onProgress,
    required VoidCallback onSuccess,
    required Function(String err) onError,
  }) async {
    if (_isServerRunning) return;

    try {
      // 1. Iniciar servidor TCP en puerto dinámico
      _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      final port = _tcpServer!.port;
      _isServerRunning = true;
      notifyListeners();

      onProgress('Servidor sincronizacion iniciado en puerto $port. Esperando conexion...');

      // Escuchar conexiones entrantes
      _tcpServer!.listen((Socket client) async {
        onProgress('Dispositivo conectado desde ${client.remoteAddress.address}. Transfiriendo datos...');
        try {
          final encryptedPayload = await exportData(passphrase);
          if (encryptedPayload != null) {
            client.write(encryptedPayload);
            await client.flush();
            onProgress('Datos enviados exitosamente. Cerrando conexion.');
            onSuccess();
          } else {
            onError('No se pudieron exportar los datos locales.');
          }
        } catch (e) {
          onError('Error en transferencia: $e');
        } finally {
          client.close();
        }
      });

      // 2. Iniciar socket UDP para responder a peticiones de descubrimiento
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 44445);
      _udpSocket!.broadcastEnabled = true;

      final localIp = await _getLocalIp();
      onProgress('IP Local: $localIp. Esperando descubrimiento...');

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            final msg = utf8.decode(datagram.data);
            if (msg.startsWith('DULCENAV_SYNC_DISCOVER:')) {
              // Responder con nuestra dirección IP y puerto TCP
              final response = 'DULCENAV_SYNC_RESPONSE:$localIp:$port';
              _udpSocket!.send(utf8.encode(response), datagram.address, datagram.port);
            }
          }
        }
      });
    } catch (e) {
      _isServerRunning = false;
      notifyListeners();
      onError('Error al iniciar servicios LAN: $e');
    }
  }

  // Detener servidor local
  void stopLanServer() {
    _tcpServer?.close();
    _udpSocket?.close();
    _tcpServer = null;
    _udpSocket = null;
    _isServerRunning = false;
    notifyListeners();
    debugPrint('[DulceSyncService] Servidores LAN detenidos.');
  }

  // Buscar y conectarse a un servidor local
  Future<void> syncFromLanDevice(
    String passphrase, {
    required Function(String status) onProgress,
    required VoidCallback onSuccess,
    required Function(String err) onError,
  }) async {
    RawDatagramSocket? searchSocket;
    try {
      onProgress('Escaneando red local por otros dispositivos...');

      searchSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      searchSocket.broadcastEnabled = true;

      // Mandar broadcast UDP en puerto 44445
      searchSocket.send(
        utf8.encode('DULCENAV_SYNC_DISCOVER:client'),
        InternetAddress('255.255.255.255'),
        44445,
      );

      // Esperar respuesta
      String? serverIp;
      int? serverPort;
      final completer = Completer<void>();

      searchSocket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = searchSocket!.receive();
          if (datagram != null) {
            final response = utf8.decode(datagram.data);
            if (response.startsWith('DULCENAV_SYNC_RESPONSE:')) {
              final parts = response.split(':');
              if (parts.length >= 3) {
                serverIp = parts[1];
                serverPort = int.tryParse(parts[2]);
                completer.complete();
              }
            }
          }
        }
      });

      // Timeout tras 5 segundos de búsqueda
      await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      });

      searchSocket.close();

      if (serverIp == null || serverPort == null) {
        onError('No se encontraron dispositivos DulceNav activos en la red local.');
        return;
      }

      onProgress('Dispositivo encontrado en $serverIp:$serverPort. Conectando...');

      // Conectarse mediante TCP y recibir el payload cifrado
      final Socket socket = await Socket.connect(serverIp!, serverPort!, timeout: const Duration(seconds: 5));
      final StringBuffer buffer = StringBuffer();

      socket.listen(
        (data) {
          buffer.write(utf8.decode(data));
        },
        onDone: () async {
          socket.close();
          onProgress('Datos cifrados recibidos. Descifrando...');
          final success = await importData(passphrase, buffer.toString());
          if (success) {
            onSuccess();
          } else {
            onError('Error al descifrar los datos. Verifique la frase de sincronizacion.');
          }
        },
        onError: (err) {
          socket.close();
          onError('Error de red durante la transferencia: $err');
        },
      );
    } catch (e) {
      searchSocket?.close();
      onError('Excepcion al sincronizar: $e');
    }
  }

  // Método auxiliar para obtener la IP local IPv4 del dispositivo
  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }
}
