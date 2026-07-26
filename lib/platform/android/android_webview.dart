// ==============================================================
// DulceNav - android_webview.dart
// WebView para Android utilizando Android System WebView nativo.
// Motor: flutter_inappwebview.
// ==============================================================

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/webview_scripts.dart';
import '../../core/services/permission_manager.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/tab_manager.dart';
import '../../core/services/theme_service.dart';
import '../../features/security/ad_blocker.dart';
import '../../features/security/cosmetic_blocker.dart';

class AndroidWebView extends StatefulWidget {
  final String initialUrl;
  final String tabId;
  final bool isIncognito;
  final Function(String url)? onUrlChanged;
  final Function(String title)? onTitleChanged;
  final Function(bool loading)? onLoadingChanged;
  final Function(int count)? onRequestBlocked;
  final Function(dynamic message)? onWebMessageReceived;
  final Function(String error)? onReceivedError;

  const AndroidWebView({
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

  @override
  State<AndroidWebView> createState() => AndroidWebViewState();
}

class AndroidWebViewState extends State<AndroidWebView> {
  InAppWebViewController? _webViewController;
  bool _initialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    // Registrar el State en la pestaña correspondiente en TabManager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final tabManager = context.read<TabManager>();
        final tab = tabManager.tabs.firstWhere((t) => t.id == widget.tabId);
        tab.controller = this;
      } catch (_) {}
    });
  }

  // ── API unificada pública ───────────────────────────────────

  Future<void> loadUrl(String url) async {
    if (_initialized && _webViewController != null) {
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
  }

  Future<void> goBack() async {
    if (_initialized && _webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
    }
  }

  Future<void> goForward() async {
    if (_initialized && _webViewController != null && await _webViewController!.canGoForward()) {
      await _webViewController!.goForward();
    }
  }

  Future<void> reload() async {
    if (_initialized && _webViewController != null) {
      await _webViewController!.reload();
    }
  }

  Future<void> stopLoading() async {
    if (_initialized && _webViewController != null) {
      await _webViewController!.stopLoading();
    }
  }

  Future<void> setZoomFactor(double zoomFactor) async {
    if (_initialized && _webViewController != null) {
      await _webViewController!.evaluateJavascript(source: '''
        document.body.style.zoom = "$zoomFactor";
        var viewport = document.querySelector('meta[name="viewport"]');
        if (viewport) {
          viewport.setAttribute('content', 'width=device-width, initial-scale=$zoomFactor');
        }
      ''');
    }
  }

  Future<void> reloadBypassingCache() async {
    if (_initialized && _webViewController != null) {
      await _webViewController!.reload();
    }
  }

  Future<String> getPageText() async {
    if (_initialized && _webViewController != null) {
      final dynamic result = await _webViewController!.evaluateJavascript(
        source: 'document.body.innerText || document.body.textContent || ""',
      );
      return result?.toString() ?? '';
    }
    return '';
  }

  Future<String> getPageHtml() async {
    if (_initialized && _webViewController != null) {
      final dynamic result = await _webViewController!.evaluateJavascript(
        source: 'document.documentElement.outerHTML || ""',
      );
      return result?.toString() ?? '';
    }
    return '';
  }

  Future<void> autofillCredentials(String username, String password) async {
    if (_initialized && _webViewController != null) {
      final String code = '''
        (() => {
          const uInput = document.querySelector("input[type='text'], input[type='email'], input[name*='user'], input[name*='login']");
          const pInput = document.querySelector("input[type='password']");
          if (uInput) {
            uInput.value = ${jsonEncode(username)};
            uInput.dispatchEvent(new Event('input', { bubbles: true }));
          }
          if (pInput) {
            pInput.value = ${jsonEncode(password)};
            pInput.dispatchEvent(new Event('input', { bubbles: true }));
          }
        })();
      ''';
      await _webViewController!.evaluateJavascript(source: code);
    }
  }

  Future<dynamic> executeScript(String code) async {
    if (_initialized && _webViewController != null) {
      return await _webViewController!.evaluateJavascript(source: code);
    }
    return null;
  }

  Future<void> suspendRenderer() async {
    if (_initialized && _webViewController != null) {
      await _webViewController!.pauseTimers();
    }
  }

  Future<void> resumeRenderer() async {
    if (_initialized && _webViewController != null) {
      await _webViewController!.resumeTimers();
    }
  }

  Future<void> pause() async {
    await suspendRenderer();
  }

  Future<void> resume() async {
    await resumeRenderer();
  }

  Future<void> updateContextMenuSetting(bool enabled) async {
    if (_initialized && _webViewController != null) {
      await _webViewController!.evaluateJavascript(
        source: 'window.dulceContextMenuEnabled = $enabled;',
      );
    }
  }

  // Returns a JSON string with the cookies for the given domain.
  Future<String> getCookiesForDomain(String domain) async {
    if (!_initialized || _webViewController == null) return '[]';
    try {
      final cookies = await CookieManager.instance().getCookies(url: WebUri("https://$domain"));
      final List<Map<String, String>> result = [];
      for (final cookie in cookies) {
        result.add({
          'name': cookie.name,
          'value': cookie.value.toString(),
        });
      }
      return jsonEncode(result);
    } catch (e) {
      debugPrint('[AndroidWebView] getCookiesForDomain error: $e');
      return '[]';
    }
  }

  // Clears cookies for a specific domain
  Future<void> clearCookiesForDomain(String domain) async {
    if (!_initialized || _webViewController == null) return;
    try {
      await CookieManager.instance().deleteCookies(url: WebUri("https://$domain"));
      debugPrint('[AndroidWebView] Cookies cleared for domain: $domain');
    } catch (e) {
      debugPrint('[AndroidWebView] clearCookiesForDomain error: $e');
    }
  }

  Future<void> setLowMemoryMode() async {}
  Future<void> setNormalMemoryMode() async {}

  // ── Bloqueo Cosmético por Dominio ─────────────────────────
  // Llamado en onLoadStop: inyecta solo las reglas del dominio actual.
  // No afecta scripts globales de la página.
  Future<void> _applyCosmeticRules(
    InAppWebViewController ctrl,
    String domain,
  ) async {
    if (!StorageService.instance.cosmeticBlockEnabled) return;
    if (domain.isEmpty) return;

    final String script = CosmeticBlocker.instance.getCosmeticScript(domain);
    if (script.isNotEmpty) {
      try {
        await ctrl.evaluateJavascript(source: script);
        debugPrint('[AndroidWebView] Cosmético inyectado para: $domain');
      } catch (e) {
        debugPrint('[AndroidWebView] Error al inyectar cosmético: $e');
      }
    }
  }

  // ── Color de fondo del sitio ──────────────────────────────────
  Future<void> _extractThemeColor() async {
    if (_webViewController == null) return;
    try {
      final dynamic colorStr = await _webViewController!.evaluateJavascript(source: '''
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

  // ── Permisos ────────────────────────────────────────────────
  String _mapPermissionResource(PermissionResourceType resource) {
    final name = resource.toString().split('.').last.toLowerCase();
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
                backgroundColor: DulceColors.primary,
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
        return Icon(Icons.videocam_rounded, color: DulceColors.primary);
      case 'microphone':
        return Icon(Icons.mic_rounded, color: DulceColors.primary);
      case 'location':
        return Icon(Icons.location_on_rounded, color: DulceColors.primary);
      case 'notifications':
        return Icon(Icons.notifications_active_rounded, color: DulceColors.primary);
      case 'clipboard':
        return Icon(Icons.assignment_rounded, color: DulceColors.primary);
      default:
        return Icon(Icons.security_rounded, color: DulceColors.primary);
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Container(
        color: DulceColors.background,
        child: Center(
          child: Text(
            'Error al iniciar WebView:\n$_initError',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.redAccent, fontFamily: 'Outfit'),
          ),
        ),
      );
    }

    final adBlocker = context.read<AdBlocker>();
    final adBlockScript = adBlocker.generateBlockScript();

    // Configurar e inyectar scripts al inicio del documento
    final List<UserScript> initialScripts = [
      UserScript(
        source: WebViewScripts.androidShimScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: WebViewScripts.privacyScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: WebViewScripts.downloadInterceptorScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: WebViewScripts.ddgAdBlockScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: WebViewScripts.mediaDetectionScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: WebViewScripts.passwordDetectionScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: WebViewScripts.contextMenuInterceptorScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: WebViewScripts.fingerprintMaskScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: 'window.dulceIncognitoMode = ${widget.isIncognito}; window.dulceAutofillEnabled = ${StorageService.instance.autofillEnabled}; window.dulceAutofillDisableInIncognito = ${StorageService.instance.autofillDisableInIncognito};',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: WebViewScripts.autofillScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: 'window.dulceContextMenuEnabled = ${StorageService.instance.contextMenuEnabled};',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    ];

    if (adBlockScript.isNotEmpty) {
      initialScripts.add(UserScript(
        source: adBlockScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ));
    }

    final tabManager = context.read<TabManager>();
    DulceTab? tab;
    try {
      tab = tabManager.tabs.firstWhere((t) => t.id == widget.tabId);
    } catch (_) {}

    InAppWebViewKeepAlive? keepAliveToken;
    if (tab != null) {
      tab.keepAliveToken ??= InAppWebViewKeepAlive();
      keepAliveToken = tab.keepAliveToken as InAppWebViewKeepAlive;
    }

    return InAppWebView(
      keepAlive: keepAliveToken,
      initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
      initialSettings: InAppWebViewSettings(
        userAgent: 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36',
        preferredContentMode: UserPreferredContentMode.MOBILE,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
        incognito: widget.isIncognito,
        cacheEnabled: !widget.isIncognito,
        safeBrowsingEnabled: true,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>(initialScripts),
      onWebViewCreated: (controller) {
        _webViewController = controller;

        // Registrar el JavaScript handler de comunicación
        controller.addJavaScriptHandler(
          handlerName: 'webMessage',
          callback: (args) {
            if (args.isNotEmpty && widget.onWebMessageReceived != null) {
              final rawMsg = args[0];
              try {
                // Pasarlo al listener unificado en browser_screen.dart
                widget.onWebMessageReceived!(rawMsg);
              } catch (e) {
                debugPrint('[AndroidWebView] Error al procesar JS message: $e');
              }
            }
          },
        );

        setState(() {
          _initialized = true;
        });
      },
      onLoadStart: (controller, url) {
        if (widget.onLoadingChanged != null) widget.onLoadingChanged!(true);
        if (url != null && widget.onUrlChanged != null) {
          widget.onUrlChanged!(url.toString());
        }
      },
      onLoadStop: (controller, url) async {
        if (widget.onLoadingChanged != null) widget.onLoadingChanged!(false);
        if (url != null && widget.onUrlChanged != null) {
          widget.onUrlChanged!(url.toString());
        }
        
        final title = await controller.getTitle();
        if (title != null && widget.onTitleChanged != null) {
          widget.onTitleChanged!(title);
        }

        // Extraer color del sitio
        _extractThemeColor();

        // Inyectar bloqueo cosmético para el dominio actual
        final String domain = url?.host.toLowerCase() ?? '';
        await _applyCosmeticRules(controller, domain);
      },
      onProgressChanged: (controller, progress) {
        if (progress >= 100) {
          if (widget.onLoadingChanged != null) widget.onLoadingChanged!(false);
        } else {
          if (widget.onLoadingChanged != null) widget.onLoadingChanged!(true);
        }
      },
      onReceivedError: (controller, request, error) {
        debugPrint('[AndroidWebView] Error en carga: ${error.description}');
        // Filtrar errores menores de recursos secundarios (solo notificar si es del main frame)
        if (request.isForMainFrame ?? true) {
          widget.onReceivedError?.call(error.description);
        }
      },
      onPermissionRequest: (controller, permissionRequest) async {
        final List<PermissionResourceType> grantedResources = [];
        final manager = PermissionManager.instance;
        
        for (var resource in permissionRequest.resources) {
          final String permissionType = _mapPermissionResource(resource);
          final decision = manager.getDecisionFor(permissionRequest.origin.toString(), permissionType);
          
          bool allowed = false;
          if (decision == PermissionDecision.allow) {
            allowed = true;
          } else if (decision == PermissionDecision.ask) {
            final userApproved = await _showPermissionDialog(permissionRequest.origin.toString(), permissionType);
            if (userApproved == true) {
              manager.setDecisionFor(permissionRequest.origin.toString(), permissionType, PermissionDecision.allow);
              allowed = true;
            } else if (userApproved == false) {
              manager.setDecisionFor(permissionRequest.origin.toString(), permissionType, PermissionDecision.block);
            }
          }
          
          if (allowed) {
            grantedResources.add(resource);
          }
        }
        
        return PermissionResponse(
          resources: grantedResources,
          action: grantedResources.isNotEmpty
              ? PermissionResponseAction.GRANT
              : PermissionResponseAction.DENY,
        );
      },
    );
  }

  @override
  void dispose() {
    if (_initialized) {
      if (widget.isIncognito || StorageService.instance.clearOnClose) {
        CookieManager.instance().deleteAllCookies();
        WebStorageManager.instance().deleteAllData();
      }
    }
    super.dispose();
  }
}
