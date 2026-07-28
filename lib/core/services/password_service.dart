// ==============================================================
// DulceNav - password_service.dart
// Gestor de contraseñas cifrado y seguro.
// Soporta DPAPI nativo en Windows y Android Keystore en Android.
// 100% libre de dependencias C++ ATL / MSVC complejas.
// ==============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'storage_service.dart';

class PasswordEntry {
  final String domain;
  final String username;
  final String password;
  final int lastModified;

  PasswordEntry({
    required this.domain,
    required this.username,
    required this.password,
    required this.lastModified,
  });
}

class PasswordService extends ChangeNotifier {
  PasswordService._();
  static final PasswordService instance = PasswordService._();

  List<PasswordEntry> _entries = [];
  List<PasswordEntry> get entries => _entries;

  int? _lastVerifiedTimestamp;
  Timer? _clearClipboardTimer;

  bool get _isGracePeriodValid {
    final lastVerified = _lastVerifiedTimestamp;
    if (lastVerified == null) return false;
    final graceMins = StorageService.instance.passwordGracePeriodMinutes;
    if (graceMins == -1) {
      return true;
    }
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastVerified;
    return elapsed < (graceMins * 60 * 1000);
  }

  Future<bool> isBiometricsAvailable() async {
    try {
      final localAuth = LocalAuthentication();
      final bool canAuthenticateWithBiometrics = await localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestAccess(BuildContext context, String reason) async {
    final storage = StorageService.instance;
    if (!storage.passwordProtectionEnabled) return true;
    if (_isGracePeriodValid) return true;

    bool authenticated = false;

    if (!storage.passwordCustomPinOnly) {
      try {
        final localAuth = LocalAuthentication();
        authenticated = await localAuth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
      } catch (e) {
        debugPrint('[PasswordService] Error en local_auth: $e');
      }
    }

    if (!authenticated) {
      final pinHash = storage.passwordCustomPinHash;
      if (pinHash.isNotEmpty) {
        authenticated = await _showCustomPinDialog(context);
      }
    }

    if (authenticated) {
      _lastVerifiedTimestamp = DateTime.now().millisecondsSinceEpoch;
    }

    return authenticated;
  }

  Future<bool> _showCustomPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    final storage = StorageService.instance;
    final expectedHash = storage.passwordCustomPinHash;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text(
              'Confirmar Identidad',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu clave personalizada de DulceNav para acceder:',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Clave / PIN',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final input = controller.text.trim();
              if (input.isNotEmpty) {
                final bytes = utf8.encode(input);
                final digest = sha256.convert(bytes);
                if (digest.toString() == expectedHash) {
                  Navigator.of(ctx).pop(true);
                  return;
                }
              }
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Clave incorrecta', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void copyToClipboardSecure(String value) {
    Clipboard.setData(ClipboardData(text: value));
    _clearClipboardTimer?.cancel();
    _clearClipboardTimer = Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
      debugPrint('[PasswordService] Portapapeles limpiado automáticamente.');
    });
  }

  void resetGracePeriod() {
    _lastVerifiedTimestamp = null;
  }

  @override
  void dispose() {
    _clearClipboardTimer?.cancel();
    super.dispose();
  }

  SharedPreferences? _prefs;
  static const _channel = MethodChannel('com.dulce.nav/keystore');

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Cargar todas las credenciales cifradas
  Future<void> loadCredentials() async {
    try {
      await _initPrefs();
      final keys = _prefs!.getKeys();
      final List<PasswordEntry> temp = [];
      
      for (final key in keys) {
        if (key.startsWith('pwd_sec_')) {
          final parts = key.replaceFirst('pwd_sec_', '').split('_');
          if (parts.length >= 2) {
            final domain = parts[0];
            final username = parts.sublist(1).join('_');
            final encryptedBase64 = _prefs!.getString(key) ?? '';
            final keyTime = key.replaceFirst('pwd_sec_', 'pwd_time_');
            final lastModified = _prefs!.getInt(keyTime) ?? DateTime.now().millisecondsSinceEpoch;
            
            final decrypted = await _decrypt(encryptedBase64);
            if (decrypted != null) {
              temp.add(PasswordEntry(
                domain: domain,
                username: username,
                password: decrypted,
                lastModified: lastModified,
              ));
            }
          }
        }
      }
      
      _entries = temp;
      notifyListeners();
      debugPrint('[PasswordService] Credenciales cargadas exitosamente. Conteo: ${_entries.length}');
    } catch (e) {
      debugPrint('[PasswordService] Error al cargar credenciales: $e');
    }
  }

  // Guardar credenciales cifradas
  Future<void> saveCredentials(String domain, String username, String password, {int? lastModified}) async {
    if (domain.isEmpty || username.isEmpty || password.isEmpty) return;
    await _initPrefs();
    
    final cleanDomain = _sanitizeDomain(domain);
    final key = 'pwd_sec_${cleanDomain}_$username';
    final keyTime = 'pwd_time_${cleanDomain}_$username';
    
    final existingTime = _prefs!.getInt(keyTime);
    final targetTime = lastModified ?? DateTime.now().millisecondsSinceEpoch;
    
    if (existingTime != null && existingTime >= targetTime) {
      debugPrint('[PasswordService] Credencial local mas reciente para $domain. Omitiendo.');
      return;
    }
    
    final encrypted = await _encrypt(password);
    if (encrypted != null) {
      await _prefs!.setString(key, encrypted);
      await _prefs!.setInt(keyTime, targetTime);
      await loadCredentials(); // Recargar lista
    }
  }

  // Obtener contraseña para un dominio y usuario especifico
  Future<String?> getPassword(String domain, String username) async {
    await _initPrefs();
    final cleanDomain = _sanitizeDomain(domain);
    final key = 'pwd_sec_${cleanDomain}_$username';
    final encrypted = _prefs!.getString(key);
    if (encrypted != null) {
      return await _decrypt(encrypted);
    }
    return null;
  }

  // Obtener todas las credenciales de un dominio
  List<PasswordEntry> getEntriesForDomain(String domain) {
    final cleanDomain = _sanitizeDomain(domain);
    return _entries.where((entry) => entry.domain == cleanDomain).toList();
  }

  // Eliminar credencial cifrada
  Future<void> deleteCredentials(String domain, String username) async {
    await _initPrefs();
    final cleanDomain = _sanitizeDomain(domain);
    final key = 'pwd_sec_${cleanDomain}_$username';
    await _prefs!.remove(key);
    await loadCredentials(); // Recargar lista
  }

  // Eliminar todas las contraseñas guardadas
  Future<void> deleteAllCredentials() async {
    await _initPrefs();
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith('pwd_sec_')) {
        await _prefs!.remove(key);
      }
    }
    await loadCredentials();
  }

  String _sanitizeDomain(String domain) {
    return domain.trim().toLowerCase().replaceAll('www.', '');
  }

  // Cifrar datos según la plataforma activa
  Future<String?> _encrypt(String text) async {
    if (text.isEmpty) return null;

    if (!kIsWeb) {
      // Caso 1: Windows DPAPI FFI
      if (Platform.isWindows) {
        Pointer<CRYPT_INTEGER_BLOB>? pDataIn;
        Pointer<CRYPT_INTEGER_BLOB>? pDataOut;
        Pointer<Uint8>? pBytes;
        
        try {
          final plaintextBytes = utf8.encode(text);
          pDataIn = calloc<CRYPT_INTEGER_BLOB>();
          pDataOut = calloc<CRYPT_INTEGER_BLOB>();
          
          pBytes = calloc<Uint8>(plaintextBytes.length);
          for (var i = 0; i < plaintextBytes.length; i++) {
            pBytes[i] = plaintextBytes[i];
          }
          
          pDataIn.ref.cbData = plaintextBytes.length;
          pDataIn.ref.pbData = pBytes;
          
          final result = CryptProtectData(
            pDataIn,
            nullptr,
            nullptr,
            nullptr,
            nullptr,
            0,
            pDataOut,
          );
          
          if (result == 0) {
            debugPrint('[PasswordService] Error en CryptProtectData: ${GetLastError()}');
            return null;
          }
          
          final cbData = pDataOut.ref.cbData;
          final pbData = pDataOut.ref.pbData;
          
          final encryptedBytes = <int>[];
          for (var i = 0; i < cbData; i++) {
            encryptedBytes.add(pbData[i]);
          }
          
          LocalFree(pbData.cast());
          
          return base64Encode(encryptedBytes);
        } catch (e) {
          debugPrint('[PasswordService] Excepcion al cifrar con DPAPI: $e');
          return null;
        } finally {
          if (pBytes != null) calloc.free(pBytes);
          if (pDataIn != null) calloc.free(pDataIn);
          if (pDataOut != null) calloc.free(pDataOut);
        }
      }
      // Caso 2: Android Keystore nativo
      else if (Platform.isAndroid) {
        try {
          final String? encrypted = await _channel.invokeMethod<String>('encrypt', {'data': text});
          return encrypted;
        } catch (e) {
          debugPrint('[PasswordService] Error al cifrar en Android Keystore: $e');
          return null;
        }
      }
    }

    // Fallback de Base64 para testing / no-Windows
    return base64Encode(utf8.encode(text));
  }

  // Descifrar datos según la plataforma activa
  Future<String?> _decrypt(String base64Text) async {
    if (base64Text.isEmpty) return null;

    if (!kIsWeb) {
      // Caso 1: Windows DPAPI FFI
      if (Platform.isWindows) {
        Pointer<CRYPT_INTEGER_BLOB>? pDataIn;
        Pointer<CRYPT_INTEGER_BLOB>? pDataOut;
        Pointer<Uint8>? pBytes;

        try {
          final encryptedBytes = base64Decode(base64Text);
          pDataIn = calloc<CRYPT_INTEGER_BLOB>();
          pDataOut = calloc<CRYPT_INTEGER_BLOB>();
          
          pBytes = calloc<Uint8>(encryptedBytes.length);
          for (var i = 0; i < encryptedBytes.length; i++) {
            pBytes[i] = encryptedBytes[i];
          }
          
          pDataIn.ref.cbData = encryptedBytes.length;
          pDataIn.ref.pbData = pBytes;
          
          final result = CryptUnprotectData(
            pDataIn,
            nullptr,
            nullptr,
            nullptr,
            nullptr,
            0,
            pDataOut,
          );
          
          if (result == 0) {
            debugPrint('[PasswordService] Error en CryptUnprotectData: ${GetLastError()}');
            return null;
          }
          
          final cbData = pDataOut.ref.cbData;
          final pbData = pDataOut.ref.pbData;
          
          final decryptedBytes = <int>[];
          for (var i = 0; i < cbData; i++) {
            decryptedBytes.add(pbData[i]);
          }
          
          LocalFree(pbData.cast());
          
          return utf8.decode(decryptedBytes);
        } catch (e) {
          debugPrint('[PasswordService] Excepcion al descifrar con DPAPI: $e');
          return null;
        } finally {
          if (pBytes != null) calloc.free(pBytes);
          if (pDataIn != null) calloc.free(pDataIn);
          if (pDataOut != null) calloc.free(pDataOut);
        }
      }
      // Caso 2: Android Keystore nativo
      else if (Platform.isAndroid) {
        try {
          final String? decrypted = await _channel.invokeMethod<String>('decrypt', {'data': base64Text});
          return decrypted;
        } catch (e) {
          debugPrint('[PasswordService] Error al descifrar en Android Keystore: $e');
          return null;
        }
      }
    }

    // Fallback para testing / no-Windows
    try {
      return utf8.decode(base64Decode(base64Text));
    } catch (_) {
      return null;
    }
  }

  // Métodos públicos para exponer cifrado y descifrado nativo
  Future<String?> encryptText(String text) => _encrypt(text);
  Future<String?> decryptText(String base64Text) => _decrypt(base64Text);
}
