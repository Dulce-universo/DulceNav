// ==============================================================
// DulceNav - windows_webview.dart v1.2.1
// WebView para Windows usando Edge/WebView2 nativo del sistema.
// Motor: webview_windows (NO instala nada extra).
// Edge ya viene incluido en Windows 10 (1803+) y Windows 11.
//
// INTEGRACION CON FASE 2:
//   - Script de privacidad: inyectado una vez al inicializar
//   - Script de bloqueo JS: inyectado una vez al inicializar
//   - Clasificacion de sitio: llamada en cada cambio de URL
//
// NOTA SOBRE addScriptToExecuteOnDocumentCreated():
//   Registra un script que se ejecuta en CADA documento nuevo
//   cargado. Solo hay que llamarlo UNA vez por script.
//   No acumular llamadas en el listener de loadingState.
// ==============================================================

import 'dart:async';
import 'dart:io' show Directory, File;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/webview_scripts.dart';
import '../../core/services/permission_manager.dart';
import '../../core/services/tab_manager.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/utils/url_utils.dart';
import '../../features/security/ad_blocker.dart';
import '../../features/security/cosmetic_blocker.dart';
import '../../features/security/site_classifier.dart';

class WindowsWebView extends StatefulWidget {
  final String initialUrl;
  final String tabId;
  final bool isIncognito;
  final Function(String url)? onUrlChanged;
  final Function(String title)? onTitleChanged;
  final Function(bool loading)? onLoadingChanged;
  final Function(int count)? onRequestBlocked;
  final Function(dynamic message)? onWebMessageReceived;
  final Function(String error)? onReceivedError;

  const WindowsWebView({
    super.key,
    required this.initialUrl,
    required this.tabId,
    this.isIncognito = false,
    this.onUrlChanged,
    this.onTitleChanged,
    this.onLoadingChanged,
    this.onRequestBlocked,
    this.onWebMessageReceived,
    this.onReceivedError,
  });

  static bool _envInitialized = false;

  static Future<void> ensureEnvironmentInitialized() async {
    if (_envInitialized) return;
    try {
      final storage = StorageService.instance;
      final maxCacheMb = storage.maxCacheSizeMb;
      final cacheSizeBytes = maxCacheMb * 1024 * 1024;

      // Clean cache path on drive D
      const userDataPath = r'D:\Proyectos\DulceNav\.webview_data';

      // Chromium arguments to limit cache size and disable saving password/autofill
      String args = '--disk-cache-size=$cacheSizeBytes '
          '--disable-features=PasswordManager,PasswordManagerOnboarding,Autofill '
          '--disable-save-password-bubble '
          '--disable-autofill';

      final dnsMode = storage.secureDnsMode;
      if (dnsMode == 'cloudflare') {
        args += ' --enable-features=DnsOverHttps --dns-over-https-templates=https://cloudflare-dns.com/dns-query';
      } else if (dnsMode == 'google') {
        args += ' --enable-features=DnsOverHttps --dns-over-https-templates=https://dns.google/dns-query';
      } else if (dnsMode == 'quad9') {
        args += ' --enable-features=DnsOverHttps --dns-over-https-templates=https://dns.quad9.net/dns-query';
      }

      await WebviewController.initializeEnvironment(
        userDataPath: userDataPath,
        additionalArguments: args,
      );
      _envInitialized = true;
      debugPrint('[WindowsWebView] Webview environment initialized on D drive with cache size: $maxCacheMb MB');

      // Clear old cache files (>7 days) asynchronously
      if (storage.autoCleanCache) {
        unawaited(clearOldCache());
      }
    } catch (e) {
      debugPrint('[WindowsWebView] Error or already initialized environment: $e');
      _envInitialized = true; // Avoid retrying endlessly if already initialized by runtime
    }
  }

  static Future<void> clearOldCache() async {
    try {
      final dir = Directory(r'D:\Proyectos\DulceNav\.webview_data');
      if (!await dir.exists()) return;

      final now = DateTime.now();
      const differenceLimit = Duration(days: 7);
      int deletedCount = 0;

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > differenceLimit) {
              await entity.delete();
              deletedCount++;
            }
          } catch (_) {
            // Locked files can be skipped
          }
        }
      }
      debugPrint('[WindowsWebView] Cleaned $deletedCount files older than 7 days from cache.');
    } catch (e) {
      debugPrint('[WindowsWebView] Error cleaning old cache files: $e');
    }
  }

  static Future<void> clearCacheNow() async {
    try {
      final dir = Directory(r'D:\Proyectos\DulceNav\.webview_data');
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
      debugPrint('[WindowsWebView] Cache cleared manually.');
    } catch (e) {
      debugPrint('[WindowsWebView] Error clearing cache: $e');
    }
  }

  @override
  // Estado publico para GlobalKey desde BrowserScreen
  // ignore: library_private_types_in_public_api
  WindowsWebViewState createState() => WindowsWebViewState();
}

// Estado publico (sin guion bajo): requerido para GlobalKey<WindowsWebViewState>
class WindowsWebViewState extends State<WindowsWebView> {
  final WebviewController _controller = WebviewController();
  bool _initialized = false;
  String? _initError;
  String? _lastDomain;

  @override
  void initState() {
    super.initState();
    _initWebView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final tabManager = context.read<TabManager>();
          final tab = tabManager.tabs.firstWhere((t) => t.id == widget.tabId);
          tab.controller = this;
          debugPrint('[WindowsWebView] Asignado controller a tab: ${widget.tabId}');
        } catch (_) {}
      }
    });
  }

  Future<void> _initWebView() async {
    try {
      await _controller.initialize();
      // Chrome 136 UA: compatibilidad maxima con OAuth 2.0, FedCM y todos los sitios
      await _controller.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/136.0.0.0 Safari/537.36',
      );

      if (widget.isIncognito) {
        await _controller.setCacheDisabled(true);
        await _controller.clearCookies();
        await _controller.clearCache();
      }

      // Color de fondo oscuro desde inicio (evita flash blanco)
      await _controller.setBackgroundColor(DulceColors.background);

      // Bloquear todas las ventanas emergentes
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      // ── Script 1: Privacidad y rendimiento ─────────────────
      // Se registra UNA sola vez. Se ejecuta en cada documento nuevo.
      await _controller.addScriptToExecuteOnDocumentCreated(WebViewScripts.privacyScript);

      // ── Script de Descargas ────────────────────────────────
      await _controller.addScriptToExecuteOnDocumentCreated(WebViewScripts.downloadInterceptorScript);

      // ── Script de DuckDuckGo AdBlocker ─────────────────────
      await _controller.addScriptToExecuteOnDocumentCreated(WebViewScripts.ddgAdBlockScript);

      // ── Script de Deteccion de Contenido Multimedia ────────
      await _controller.addScriptToExecuteOnDocumentCreated(WebViewScripts.mediaDetectionScript);

      final autofillEnabled = StorageService.instance.autofillEnabled;
      final autofillDisableInIncognito = StorageService.instance.autofillDisableInIncognito;
      final isInc = widget.isIncognito;

      final configScript = '''
        window.dulceIncognitoMode = $isInc;
        window.dulceAutofillEnabled = $autofillEnabled;
        window.dulceAutofillDisableInIncognito = $autofillDisableInIncognito;
      ''';
      await _controller.addScriptToExecuteOnDocumentCreated(configScript);

      // ── Script de Deteccion de Contraseñas ──────────────────
      await _controller.addScriptToExecuteOnDocumentCreated(WebViewScripts.passwordDetectionScript);

      // ── Script de Autocompletado de Credenciales ─────────────
      await _controller.addScriptToExecuteOnDocumentCreated(WebViewScripts.autofillScript);

      // ── Script de intercepcion de click derecho (Context Menu) ──
      await _controller.addScriptToExecuteOnDocumentCreated(WebViewScripts.contextMenuInterceptorScript);

      // ── Script de enmascaramiento de huella digital ───────
      await _controller.addScriptToExecuteOnDocumentCreated(WebViewScripts.fingerprintMaskScript);

      // ── Script 2: Bloqueo de anuncios ──────────────────────
      // Se lee desde AdBlocker en el momento de la inicializacion.
      // Si las listas no estan listas aun, el script estara vacio
      // y no se inyecta nada (seguro). Cuando el usuario navega
      // a una nueva pestana, el WindowsWebView se recrea y
      // obtendra el script actualizado con las listas ya cargadas.
      if (mounted) {
        final String blockScript =
            context.read<AdBlocker>().generateBlockScript();
        if (blockScript.isNotEmpty) {
          await _controller.addScriptToExecuteOnDocumentCreated(blockScript);
        }
      }

      // ── Listeners de estado ────────────────────────────────

      _controller.url.listen((String url) {
        if (url.isNotEmpty && mounted) {
          // Interceptar paginas de error de WebView2
          if (url.contains('chromewebdata') || url.contains('chrome-error://')) {
            debugPrint('[WindowsWebView] Error de carga detectado: $url');
            widget.onReceivedError?.call('No se pudo cargar la pagina. Verifica tu conexion a internet.');
            return;
          }

          // Interceptar esquema edge:// generado por WebView2 en paginas nuevas
          if (url.startsWith('edge://')) {
            debugPrint('[WindowsWebView] Interceptado esquema edge://, redirigiendo a inicio.');
            _controller.loadUrl('about:blank');
            widget.onUrlChanged?.call('about:dulcenav');
            return;
          }

          widget.onUrlChanged?.call(url);
          // Clasificar el sitio cada vez que cambia la URL
          context.read<SiteClassifier>().classify(url);

          // Site isolation cookie cleanup
          final storage = StorageService.instance;
          if (storage.siteIsolation) {
            try {
              final uri = Uri.parse(url);
              if (uri.host.isNotEmpty) {
                final newDomain = uri.host.toLowerCase();
                if (_lastDomain != null && _lastDomain != newDomain) {
                  final whitelist = storage.cookieWhitelist;
                  final isWhitelisted = whitelist.any((d) => _lastDomain!.endsWith(d) || d.endsWith(_lastDomain!));
                  if (!isWhitelisted) {
                    _controller.clearCookies();
                    debugPrint('[SiteIsolation] Cookies cleared on transition from $_lastDomain to $newDomain');
                  }
                }
                _lastDomain = newDomain;
              }
            } catch (_) {}
          }
        }
      });

      _controller.title.listen((String? title) {
        if (title != null && title.isNotEmpty) {
          widget.onTitleChanged?.call(title);
        }
      });

      _controller.loadingState.listen((LoadingState state) {
        if (mounted) {
          widget.onLoadingChanged?.call(state == LoadingState.loading);
          if (state == LoadingState.navigationCompleted) {
            _extractThemeColor();
            final contextMenuEnabled = StorageService.instance.contextMenuEnabled;
            _controller.executeScript('window.dulceContextMenuEnabled = $contextMenuEnabled;');
            // Inyectar bloqueo cosmético para el dominio actual
            _applyCosmeticRules();
          }
        }
      });

      _controller.webMessage.listen((dynamic message) {
        if (mounted) {
          widget.onWebMessageReceived?.call(message);
        }
      });

      // Navegar a la URL inicial si no es la pagina de inicio
      if (widget.initialUrl.isNotEmpty &&
          !UrlUtils.isHomePage(widget.initialUrl)) {
        await _controller.loadUrl(widget.initialUrl);
      }

      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      debugPrint('[WindowsWebView] Error al inicializar WebView2: $e');
      if (mounted) {
        setState(() => _initError = e.toString());
      }
    }
  }








  // ── Bloqueo Cosmético por Dominio ─────────────────────────
  // Se llama en cada navigationCompleted para inyectar solo las
  // reglas del dominio actual. No acumula scripts globales.
  Future<void> _applyCosmeticRules() async {
    if (!_initialized) return;
    if (!StorageService.instance.cosmeticBlockEnabled) return;
    try {
      // Obtener dominio actual desde el WebView
      final dynamic rawHost = await _controller.executeScript(
        '(function(){ try { return location.hostname; } catch(e) { return ""; } })()',
      );
      final String domain = (rawHost?.toString() ?? '')
          .replaceAll('"', '')
          .trim()
          .toLowerCase();
      if (domain.isEmpty) return;

      final String script = CosmeticBlocker.instance.getCosmeticScript(domain);
      if (script.isNotEmpty) {
        await _controller.executeScript(script);
        debugPrint('[WindowsWebView] Cosmético inyectado para: $domain');
      }
    } catch (e) {
      debugPrint('[WindowsWebView] Error al inyectar cosmético: $e');
    }
  }

  // ── Metodos publicos (accedidos via GlobalKey) ──────────────

  Future<void> loadUrl(String url) async {
    if (_initialized) await _controller.loadUrl(url);
  }

  Future<void> setLowMemoryMode() async {
    debugPrint('[WindowsWebView] setLowMemoryMode called (placeholder for MemoryUsageTargetLevel.Low)');
  }

  Future<void> setNormalMemoryMode() async {
    debugPrint('[WindowsWebView] setNormalMemoryMode called (placeholder for MemoryUsageTargetLevel.Normal)');
  }

  Future<void> suspendRenderer() async {
    if (_initialized) {
      try {
        await _controller.suspend();
        debugPrint('[WindowsWebView] Renderer suspended.');
      } catch (e) {
        debugPrint('[WindowsWebView] Error suspending renderer: $e');
      }
    }
  }

  Future<void> resumeRenderer() async {
    if (_initialized) {
      try {
        await _controller.resume();
        debugPrint('[WindowsWebView] Renderer resumed.');
      } catch (e) {
        debugPrint('[WindowsWebView] Error resuming renderer: $e');
      }
    }
  }

  Future<void> pause() async {
    await suspendRenderer();
  }

  Future<void> resume() async {
    await resumeRenderer();
  }

  Future<void> setFpsLimit(int fps) async {
    if (_initialized) {
      try {
        await _controller.setFpsLimit(fps);
        debugPrint('[WindowsWebView] Fps limit set to: $fps');
      } catch (e) {
        debugPrint('[WindowsWebView] Error setting Fps limit: $e');
      }
    }
  }

  Future<void> openDevTools() async {
    if (_initialized) {
      try {
        await _controller.openDevTools();
      } catch (e) {
        debugPrint('[WindowsWebView] Error al abrir DevTools: $e');
      }
    }
  }

  Future<void> updateContextMenuSetting(bool enabled) async {
    if (_initialized) {
      try {
        await _controller.executeScript('window.dulceContextMenuEnabled = $enabled;');
      } catch (_) {}
    }
  }
  Future<void> autofillCredentials(String username, String password) async {
    if (!_initialized) return;
    final escapedUser = username.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final escapedPass = password.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final fillScript = '''
(function(){
  var passwordInput = document.querySelector("input[type='password']");
  if (passwordInput) {
    passwordInput.value = "$escapedPass";
    passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
    passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
    
    var usernameInput = document.querySelector("input[type='text'], input[type='email'], input[name*='user'], input[name*='login']");
    if (usernameInput) {
      usernameInput.value = "$escapedUser";
      usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
      usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }
})();
''';
    try {
      await _controller.executeScript(fillScript);
    } catch (_) {}
  }

  Future<dynamic> executeScript(String code) async {
    if (_initialized) {
      try {
        return await _controller.executeScript(code);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> goBack() async {
    if (_initialized) await _controller.goBack();
  }

  Future<void> goForward() async {
    if (_initialized) await _controller.goForward();
  }

  Future<void> reload() async {
    if (_initialized) await _controller.reload();
  }

  Future<void> stopLoading() async {
    if (_initialized) await _controller.stop();
  }

  Future<void> setZoomFactor(double zoomFactor) async {
    if (_initialized) {
      try {
        await _controller.setZoomFactor(zoomFactor);
      } catch (e) {
        debugPrint('[WindowsWebView] Error al ajustar zoom: $e');
      }
    }
  }

  Future<void> reloadBypassingCache() async {
    if (_initialized) {
      try {
        await _controller.executeScript('window.location.reload(true);');
      } catch (_) {
        await _controller.reload();
      }
    }
  }

  Future<String> getPageText() async {
    if (!_initialized) return '';
    try {
      final dynamic result = await _controller.executeScript('document.body.innerText');
      return (result is String) ? result : '';
    } catch (_) {
      return '';
    }
  }

  Future<String> getPageHtml() async {
    if (!_initialized) return '';
    try {
      final dynamic result = await _controller.executeScript('document.documentElement.outerHTML');
      return (result is String) ? result : '';
    } catch (_) {
      return '';
    }
  }

  // Returns a JSON string with the cookies for the given domain.
  // Uses JS document.cookie which only exposes non-HttpOnly cookies.
  Future<String> getCookiesForDomain(String domain) async {
    if (!_initialized) return '';
    try {
      // Build a simple JSON from document.cookie key=value pairs
      const script = r'''
        (function(){
          var cookies = document.cookie;
          if (!cookies) return "[]";
          var pairs = cookies.split(";");
          var result = [];
          for (var i = 0; i < pairs.length; i++) {
            var p = pairs[i].trim();
            var idx = p.indexOf("=");
            if (idx > 0) {
              result.push({name: p.slice(0, idx), value: p.slice(idx + 1)});
            }
          }
          return JSON.stringify(result);
        })()
      ''';
      final dynamic result = await _controller.executeScript(script);
      return (result is String) ? result : '[]';
    } catch (e) {
      debugPrint('[WindowsWebView] getCookiesForDomain error: $e');
      return '[]';
    }
  }

  // Clears cookies for a specific domain using the native clearCookies API.
  Future<void> clearCookiesForDomain(String domain) async {
    if (!_initialized) return;
    try {
      // WebView2 clearCookies clears all cookies in the session.
      // For domain-specific clearing, we expire them via JS first.
      final script = '''
        (function(){
          var cookies = document.cookie.split(";");
          for (var i = 0; i < cookies.length; i++) {
            var cookie = cookies[i];
            var eqPos = cookie.indexOf("=");
            var name = eqPos > -1 ? cookie.substring(0, eqPos).trim() : cookie.trim();
            document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;domain=.$domain";
            document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/";
          }
        })()
      ''';
      await _controller.executeScript(script);
      debugPrint('[WindowsWebView] Cookies expired via JS for domain: $domain');
    } catch (e) {
      debugPrint('[WindowsWebView] clearCookiesForDomain error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return _WebViewErrorWidget(
        error: _initError!,
        onRetry: () {
          if (!mounted) return;
          setState(() {
            _initError = null;
            _initialized = false;
          });
          _initWebView();
        },
        onGoHome: () {
          if (!mounted) return;
          setState(() {
            _initError = null;
            _initialized = false;
          });
          _initWebView();
        },
      );
    }
    if (!_initialized) {
      return const _WebViewLoadingWidget();
    }

    return Webview(
      _controller,
      permissionRequested: (
        String url,
        WebviewPermissionKind kind,
        bool isUserInitiated,
      ) {
        return _handlePermissionRequested(url, kind, isUserInitiated);
      },
    );
  }

  @override
  void dispose() {
    if (_initialized) {
      try {
        if (widget.isIncognito || StorageService.instance.clearOnClose) {
          _controller.clearCookies();
          _controller.clearCache();
        }
        _controller.dispose();
      } catch (e) {
        debugPrint('[WindowsWebView] Error en dispose del controlador: $e');
      }
    }
    super.dispose();
  }

  // ── Smart permission handling ─────────────────────────────────
  Future<WebviewPermissionDecision> _handlePermissionRequested(
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    final String permissionType = _mapPermissionKind(kind);
    final manager = PermissionManager.instance;
    final decision = manager.getDecisionFor(url, permissionType);

    if (decision == PermissionDecision.allow) {
      return WebviewPermissionDecision.allow;
    } else if (decision == PermissionDecision.block) {
      return WebviewPermissionDecision.deny;
    } else {
      // Ask
      final userApproved = await _showPermissionDialog(url, permissionType);
      if (userApproved != null) {
        if (userApproved) {
          manager.setDecisionFor(url, permissionType, PermissionDecision.allow);
          return WebviewPermissionDecision.allow;
        } else {
          manager.setDecisionFor(url, permissionType, PermissionDecision.block);
          return WebviewPermissionDecision.deny;
        }
      }
      return WebviewPermissionDecision.deny;
    }
  }

  String _mapPermissionKind(WebviewPermissionKind kind) {
    final name = kind.toString().split('.').last.toLowerCase();
    if (name.contains('camera')) return 'camera';
    if (name.contains('micro') || name.contains('audio')) return 'microphone';
    if (name.contains('geo') || name.contains('location')) return 'location';
    if (name.contains('notify')) return 'notifications';
    if (name.contains('clip') || name.contains('write') || name.contains('read')) return 'clipboard';
    return name;
  }

  Future<bool?> _showPermissionDialog(String url, String permissionType) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white12),
          ),
          title: Row(
            children: [
              _buildPermissionIcon(permissionType),
              const SizedBox(width: 10),
              Text(
                'Solicitud de permiso',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'El sitio web "$url" solicita acceso a su $permissionType. ¿Desea permitirlo?',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Bloquear', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text('Preguntar luego', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Permitir'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionIcon(String permissionType) {
    switch (permissionType) {
      case 'camera':
        return Icon(Icons.videocam_rounded, color: Color(0xFF6C63FF));
      case 'microphone':
        return Icon(Icons.mic_rounded, color: Color(0xFF6C63FF));
      case 'location':
        return Icon(Icons.location_on_rounded, color: Color(0xFF6C63FF));
      case 'notifications':
        return Icon(Icons.notifications_active_rounded, color: Color(0xFF6C63FF));
      case 'clipboard':
        return Icon(Icons.assignment_rounded, color: Color(0xFF6C63FF));
      default:
        return Icon(Icons.security_rounded, color: Color(0xFF6C63FF));
    }
  }

  // ── Color extraction logic ──────────────────────────────────────
  Future<void> _extractThemeColor() async {
    try {
      final dynamic colorStr = await _controller.executeScript('''
        (() => {
          const meta = document.querySelector('meta[name="theme-color"]');
          if (meta && meta.getAttribute('content')) {
            return meta.getAttribute('content');
          }
          const header = document.querySelector('header, .header, #header');
          if (header) {
            const bg = window.getComputedStyle(header).backgroundColor;
            if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') return bg;
          }
          const bodyBg = window.getComputedStyle(document.body).backgroundColor;
          if (bodyBg && bodyBg !== 'rgba(0, 0, 0, 0)' && bodyBg !== 'transparent') return bodyBg;
          return "";
        })()
      ''');
      if (colorStr is String && colorStr.isNotEmpty) {
        final parsedColor = _parseCssColor(colorStr);
        if (parsedColor != null && mounted) {
          ThemeService.instance.updateExtractedColor(parsedColor);
        }
      }
    } catch (_) {}
  }

  Color? _parseCssColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    var s = colorStr.trim().toLowerCase();
    if (s.startsWith('#')) {
      s = s.substring(1);
      if (s.length == 3) {
        s = s.split('').map((c) => c + c).join();
      }
      if (s.length == 6) {
        s = 'ff$s';
      }
      final val = int.tryParse(s, radix: 16);
      if (val != null) return Color(val);
    } else if (s.startsWith('rgb')) {
      final match = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)').firstMatch(s);
      if (match != null) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        final aStr = match.group(4);
        final a = aStr != null ? (double.tryParse(aStr) ?? 1.0) : 1.0;
        return Color.fromARGB((a * 255).round(), r, g, b);
      }
    }
    return null;
  }

}

// ── Widget: Cargando ───────────────────────────────────────────
class _WebViewLoadingWidget extends StatelessWidget {
  const _WebViewLoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DulceColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(
              color: DulceColors.primary,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Iniciando motor de navegacion...',
              style: TextStyle(
                fontFamily: 'Outfit',
                color: DulceColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Widget: Error con Reintentar e Ir a inicio -----------------
class _WebViewErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;

  const _WebViewErrorWidget({
    required this.error,
    this.onRetry,
    this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DulceColors.background,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DulceColors.dangerRed.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: DulceColors.dangerRed.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: DulceColors.dangerRed,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Error al inicializar el navegador',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DulceColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Asegurate de tener Microsoft Edge (WebView2) instalado.\n'
              'Requerido en Windows 10 v1803 o superior.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: DulceColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                color: DulceColors.textDisabled,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: Icon(Icons.home_outlined, size: 16),
                  label: Text(
                    'Ir a inicio',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13),
                  ),
                  onPressed: onGoHome,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DulceColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'Reintentar',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13),
                  ),
                  onPressed: onRetry,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
