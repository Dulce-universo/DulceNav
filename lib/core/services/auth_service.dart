// ============================================================
// DulceNav -- auth_service.dart v1.4.3
// Servicio de autenticacion y gestion de sesiones.
// Maneja login seguro, persistencia de cookies por dominio
// y sincronizacion de sesiones activas.
// ============================================================

import 'package:flutter/foundation.dart';
import 'storage_service.dart';

// Informacion de una sesion activa
class SessionInfo {
  final String domain;
  final DateTime lastSeen;
  final bool hasData;

  const SessionInfo({
    required this.domain,
    required this.lastSeen,
    required this.hasData,
  });
}

// Tipo del callback para sincronizar cookies desde el WebView
typedef CookieProvider = Future<String> Function(String domain);
// Tipo del callback para limpiar cookies del WebView
typedef CookieCleaner = Future<void> Function(String domain);

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Callbacks que BrowserScreen registra para acceder al WebView activo
  CookieProvider? _cookieProvider;
  CookieCleaner? _cookieCleaner;

  // -- Registro de callbacks desde BrowserScreen ------------------
  void registerCookieProvider(CookieProvider provider) {
    _cookieProvider = provider;
  }

  void registerCookieCleaner(CookieCleaner cleaner) {
    _cookieCleaner = cleaner;
  }

  // -- Getters ----------------------------------------------------
  List<String> get sessionDomains => StorageService.instance.sessionDomains;

  int get sessionCount => sessionDomains.length;

  bool get hasSavedSessions => sessionCount > 0;

  bool get autoSaveSessions => StorageService.instance.autoSaveSessions;

  bool get loginNotifications => StorageService.instance.loginNotifications;

  // Obtiene info de todas las sesiones guardadas
  List<SessionInfo> get sessions {
    final domains = sessionDomains;
    return domains.map((d) {
      final hasData = StorageService.instance.hasSessionData(d);
      return SessionInfo(
        domain: d,
        lastSeen: DateTime.now(),
        hasData: hasData,
      );
    }).toList();
  }

  // -- Configuracion de User-Agent para OAuth ---------------------
  // User-Agent estandar de Chrome para maxima compatibilidad con OAuth y FedCM.
  // Expuesto como getter publico para que BrowserScreen o el WebView puedan usarlo.
  static String get chromeUserAgent =>
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/136.0.0.0 Safari/537.36';

  // Prepara el entorno para login OAuth (Google, GitHub, etc.)
  // El WebView ya tiene el User-Agent correcto por defecto.
  // Este metodo realiza pasos adicionales de preparacion si son necesarios.
  Future<void> prepareForGoogleLogin() async {
    debugPrint('[AuthService] Preparando entorno para login de Google...');
    // El UA correcto ya esta configurado en windows_webview.dart.
    // Aqui se pueden agregar pasos adicionales en el futuro:
    //   - Verificar que las cookies esten habilitadas
    //   - Pre-cargar dominios de Google en whitelist
    //   - Asegurar que no hay bloqueo de terceros para accounts.google.com
    final storage = StorageService.instance;
    final whitelist = storage.cookieWhitelist;
    const googleDomains = ['google.com', 'accounts.google.com', 'googleapis.com'];
    bool changed = false;
    for (final d in googleDomains) {
      if (!whitelist.contains(d)) {
        whitelist.add(d);
        changed = true;
      }
    }
    if (changed) {
      await storage.setCookieWhitelist(whitelist);
      debugPrint('[AuthService] Dominios de Google agregados a whitelist de cookies.');
    }
  }

  // -- Sincronizacion de sesiones ---------------------------------

  // Registra un dominio como "con sesion activa" sin copiar cookies.
  // Se llama cuando el WebView detecta un login exitoso.
  Future<void> registerSession(String domain) async {
    if (domain.isEmpty) return;
    final domains = sessionDomains;
    if (!domains.contains(domain)) {
      domains.add(domain);
      await StorageService.instance.setSessionDomains(domains);
      debugPrint('[AuthService] Sesion registrada para: $domain');
      notifyListeners();
    }
  }

  // Sincroniza (guarda snapshot) de cookies del dominio activo.
  // Requiere que el cookieProvider este registrado.
  Future<void> syncCookies(String domain) async {
    if (domain.isEmpty) return;
    if (_cookieProvider == null) {
      debugPrint('[AuthService] No hay cookieProvider registrado, skip sync.');
      return;
    }
    try {
      final cookieJson = await _cookieProvider!(domain);
      if (cookieJson.isNotEmpty) {
        await StorageService.instance.setSessionData(domain, cookieJson);
        await registerSession(domain);
        debugPrint('[AuthService] Cookies sincronizadas para: $domain');
      }
    } catch (e) {
      debugPrint('[AuthService] Error al sincronizar cookies de $domain: $e');
    }
  }

  // -- Cierre de sesion -------------------------------------------

  // Cierra la sesion de un dominio especifico
  Future<void> clearSession(String domain) async {
    // Limpiar en WebView si el cleaner esta disponible
    if (_cookieCleaner != null) {
      try {
        await _cookieCleaner!(domain);
      } catch (e) {
        debugPrint('[AuthService] Error al limpiar cookies de $domain en WebView: $e');
      }
    }
    // Limpiar datos guardados
    await StorageService.instance.clearSessionData(domain);
    final domains = sessionDomains;
    domains.remove(domain);
    await StorageService.instance.setSessionDomains(domains);
    debugPrint('[AuthService] Sesion cerrada para: $domain');
    notifyListeners();
  }

  // Cierra todas las sesiones activas
  Future<void> clearAllSessions() async {
    final domains = List<String>.from(sessionDomains);
    for (final d in domains) {
      if (_cookieCleaner != null) {
        try {
          await _cookieCleaner!(d);
        } catch (_) {}
      }
      await StorageService.instance.clearSessionData(d);
    }
    await StorageService.instance.setSessionDomains([]);
    debugPrint('[AuthService] Todas las sesiones cerradas (${domains.length} dominios).');
    notifyListeners();
  }

  // -- Configuracion ----------------------------------------------
  Future<void> setAutoSaveSessions(bool v) async {
    await StorageService.instance.setAutoSaveSessions(v);
    notifyListeners();
  }

  Future<void> setLoginNotifications(bool v) async {
    await StorageService.instance.setLoginNotifications(v);
    notifyListeners();
  }

  // -- Deteccion de login -----------------------------------------
  // Llama a este metodo desde browser_screen cuando la URL cambia.
  // Detecta patrones tipicos de login/autenticacion completada.
  Future<void> onUrlNavigated(String url) async {
    if (!StorageService.instance.autoSaveSessions) return;
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      final domain = uri.host;
      if (domain.isEmpty) return;

      // Patrones de URL que suelen indicar login exitoso
      final path = uri.path.toLowerCase();
      const loginCompletePaths = [
        '/account',
        '/profile',
        '/dashboard',
        '/home',
        '/myaccount',
        '/my-account',
        '/settings',
        '/welcome',
      ];

      // Patrones de query que indican OAuth completado
      final query = uri.query.toLowerCase();
      const oauthParams = ['access_token', 'id_token', 'session', 'auth'];

      final hasLoginPath = loginCompletePaths.any((p) => path.startsWith(p));
      final hasOAuthParam = oauthParams.any((p) => query.contains(p));

      if (hasLoginPath || hasOAuthParam) {
        if (!sessionDomains.contains(domain)) {
          await registerSession(domain);
          if (loginNotifications) {
            debugPrint('[AuthService] Login detectado en: $domain');
          }
        }
      }
    } catch (_) {}
  }

  // Metodo de autenticacion generico y modular para preparar integraciones futuras (Firebase Auth)
  Future<Map<String, dynamic>?> signInWithGenericCredentials({
    required String providerId,
    required String token,
    String? secret,
    Map<String, dynamic>? extraData,
  }) async {
    debugPrint('[AuthService] Autenticacion generica iniciada para proveedor: $providerId');
    return {
      'uid': 'generic_user_uid_12345',
      'providerId': providerId,
      'token_length': token.length,
      'success': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
