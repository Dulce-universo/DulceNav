// ==============================================================
// DulceNav - browser_screen.dart
// Pantalla principal del navegador. Orquesta WebView,
// barra de URL, barra de pestanas, navbar y menus.
// Fase 1: navegacion funcional en Windows.
// ==============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Directory, Platform;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';


import '../../features/home/home_screen.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/services/memory_manager.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/tab_manager.dart';
import '../../core/utils/url_utils.dart';
import '../../shared/widgets/dulce_address_bar.dart';
import '../../shared/widgets/dulce_navbar.dart';
import '../../shared/widgets/security_badge.dart';
import '../../ui/screens/settings_screen.dart';
import '../../shared/widgets/dulce_webview.dart';
import '../../features/ai/dulcemind_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/download_manager.dart';
import '../../core/services/search_optimizer.dart';
import '../../features/downloads/downloads_screen.dart';
import '../../core/services/performance_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/password_service.dart';
import '../../shared/widgets/bookmarks_bar.dart';
import '../../shared/widgets/autofill_popup.dart';
import 'tab_bar_widget.dart';
import 'webview_controller.dart';

class BrowserScreen extends StatefulWidget {
  final String initialUrl;

  const BrowserScreen({
    super.key,
    this.initialUrl = 'about:dulcenav',
  });

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with WidgetsBindingObserver {

  // Controlador de estado del WebView
  late final WebViewController _webViewController;

  // Key para acceder al widget de WebView de Windows
  // Mapa de claves de WebView para cada pestaña
  final Map<String, GlobalKey<DulceWebViewState>> _webViewKeys = {};

  DulceWebViewState? get _activeWebViewState {
    if (!mounted) return null;
    try {
      final tabManager = context.read<TabManager>();
      if (tabManager.tabs.isEmpty) return null;
      final activeTabId = tabManager.activeTab.id;
      return _webViewKeys[activeTabId]?.currentState;
    } catch (_) {
      return null;
    }
  }

  // Wrapper astuto para mantener la compatibilidad con _webViewKey.currentState
  _ActiveWebViewKey get _webViewKey => _ActiveWebViewKey(this);

  // Key para el Scaffold (requerido para abrir el drawer)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // FocusNodes para el teclado y la barra de direcciones
  final FocusNode _rootFocusNode = FocusNode();
  final FocusNode _addressBarFocusNode = FocusNode();

  // Factor de zoom actual
  double _zoomFactor = 1.0;

  // Estado local del navegador
  String _currentUrl = '';
  SiteStatus _siteStatus = SiteStatus.unknown;
  String _leftDrawerType = 'history';
  final Set<String> _bypassedHosts = {};
  StreamSubscription<String>? _aiNavigationSubscription;
  Color? _adaptiveColor;

  // Estado local para el autocompletado flotante
  bool _showAutofill = false;
  double _autofillX = 0.0;
  double _autofillY = 0.0;
  double _autofillHeight = 0.0;
  String _autofillDomain = '';
  List<PasswordEntry> _autofillEntries = [];

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController();
    _currentUrl = widget.initialUrl;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadManager>().onDownloadFinished = (String fileName) {
        if (mounted) {
          _showDownloadCompletedSnackBar(fileName);
        }
      };

      // Control de limites de FPS en Modo Rendimiento
      PerformanceService.instance.onFpsLimitChanged = (int fps) async {
        if (mounted) {
          await _webViewKey.currentState?.setFpsLimit(fps);
        }
      };

      // Si arranca con modo rendimiento, aplicar de inmediato
      if (PerformanceService.instance.isGameModeActive) {
        PerformanceService.instance.onFpsLimitChanged?.call(15);
      }
    });

    _aiNavigationSubscription = DulceMindService.instance.navigationStream.listen((url) {
      if (mounted) {
        _navigate(url);
      }
    });

    // Registrar callbacks de AuthService para sincronizar cookies/sesiones
    // desde el WebView activo (se hace en post-frame para tener context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // CookieProvider: lee cookies del WebView activo
      AuthService.instance.registerCookieProvider((String domain) async {
        return await _webViewKey.currentState?.getCookiesForDomain(domain) ?? '[]';
      });

      // CookieCleaner: expira cookies del WebView activo
      AuthService.instance.registerCookieCleaner((String domain) async {
        await _webViewKey.currentState?.clearCookiesForDomain(domain);
      });

      // Registrar callbacks de hibernacion para suspender/resumir el renderer
      final tabManager = context.read<TabManager>();
      tabManager.onTabHibernated = (String tabId) {
        if (mounted && !tabManager.isActiveTab(tabId)) {
          _webViewKey.currentState?.suspendRenderer();
        }
      };
      tabManager.onTabWoken = (String tabId) {
        if (mounted && tabManager.isActiveTab(tabId)) {
          _webViewKey.currentState?.resumeRenderer();
        }
      };
      _updateIncognitoScreenshotBlock();
    });
  }

  @override
  void dispose() {
    PerformanceService.instance.onFpsLimitChanged = null;
    _aiNavigationSubscription?.cancel();
    _rootFocusNode.dispose();
    _addressBarFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _webViewController.dispose();
    super.dispose();
  }

  // Ciclo de vida de la app para gestion de memoria
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final MemoryManager mem = context.read<MemoryManager>();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        mem.onAppBackgrounded();
        _webViewKey.currentState?.suspendRenderer();
        _webViewKey.currentState?.setLowMemoryMode();
        break;
      case AppLifecycleState.resumed:
        mem.onAppResumed();
        _webViewKey.currentState?.resumeRenderer();
        _webViewKey.currentState?.setNormalMemoryMode();
        break;
      default:
        break;
    }
  }

  // Callbacks del WebView -> actualizan el controller y el estado local
  void _onUrlChanged(String url) {
    if (!mounted) return;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final urlNoParams = url.split('?')[0].split('#')[0];
      final parts = urlNoParams.split('/');
      final filename = parts.isEmpty ? '' : parts.last;
      final extPattern = RegExp(
        r'\.(zip|rar|7z|tar|gz|exe|msi|apk|dmg|iso|pdf|jpg|jpeg|png|gif|mp3|mp4|avi|mkv|docx|xlsx|pptx|txt|csv)$',
        caseSensitive: false,
      );
      if (extPattern.hasMatch(filename)) {
        _stopLoading();
        _goBack();
        _initiateDownload(url, fileName: filename);
        return;
      }
    }

    _webViewController.onUrlChanged(url);
    if (!mounted) return;
    setState(() {
      _currentUrl = url;
      _siteStatus = _classifySite(url);
    });
    if (!mounted) return;
    final tabManager = context.read<TabManager>();
    tabManager.updateTab(
      tabId: tabManager.activeTab.id,
      url: url,
    );
    _updateIncognitoScreenshotBlock();
    if (!tabManager.activeTab.isIncognito && !UrlUtils.isHomePage(url) && url.isNotEmpty) {
      final String activeTitle = tabManager.activeTab.title;
      StorageService.instance.addToHistoryWithTitle(
        (activeTitle.isEmpty || activeTitle == url) ? UrlUtils.getDomain(url) : activeTitle,
        url,
      );
    }
    // Deteccion automatica de login y registro de sesion
    AuthService.instance.onUrlNavigated(url);
  }

  void _onTitleChanged(String title) {
    if (!mounted) return;
    _webViewController.onTitleChanged(title);
    final TabManager tabs = context.read<TabManager>();
    tabs.updateTab(
      tabId: tabs.activeTab.id,
      title: title,
      url: _currentUrl,
    );
    if (!tabs.activeTab.isIncognito && !UrlUtils.isHomePage(_currentUrl) && _currentUrl.isNotEmpty) {
      StorageService.instance.addToHistoryWithTitle(title, _currentUrl);
    }
  }

  void _onLoadingChanged(bool loading) {
    if (!mounted) return;
    if (loading) {
      _webViewController.onPageStarted(_currentUrl);
    } else {
      _webViewController.onPageFinished(_currentUrl);
      // Aplicar factor de zoom al finalizar la carga
      _webViewKey.currentState?.setZoomFactor(_zoomFactor);

      if (StorageService.instance.adaptiveThemeEnabled) {
        _extractAndApplyThemeColor();
      }
    }
  }

  // Clasificacion provisional (Fase 2 usara la DB completa)
  SiteStatus _classifySite(String url) {
    if (UrlUtils.isHomePage(url)) return SiteStatus.unknown;
    final String domain = UrlUtils.getDomain(url);
    const List<String> safeDomains = <String>[
      'google.com',
      'youtube.com',
      'github.com',
      'wikipedia.org',
      'dulceapps.lovable.app',
      'microsoft.com',
      'stackoverflow.com',
    ];
    if (safeDomains.any((String d) => domain.endsWith(d))) {
      return SiteStatus.safe;
    }
    return SiteStatus.unknown;
  }

  void _updateIncognitoScreenshotBlock() {
    if (Platform.isAndroid) {
      try {
        final isInc = context.read<TabManager>().activeTab.isIncognito;
        if (isInc) {
          const MethodChannel('com.dulce.nav/window_manager').invokeMethod('addFlags');
        } else {
          const MethodChannel('com.dulce.nav/window_manager').invokeMethod('clearFlags');
        }
      } catch (e) {
        debugPrint('[BrowserScreen] Error al configurar FLAG_SECURE: $e');
      }
    }
  }

  Future<void> _extractAndApplyThemeColor() async {
    if (!mounted) return;
    try {
      final dynamic jsResult = await _webViewKey.currentState?.executeScript(
        "document.querySelector('meta[name=\"theme-color\"]')?.getAttribute('content')"
      );
      String? colorStr = jsResult?.toString();
      
      if (colorStr == null || colorStr.trim().isEmpty || colorStr == "null") {
        colorStr = _fallbackColorForUrl(_currentUrl);
      }

      if (!mounted) return;
      if (colorStr != null && colorStr.isNotEmpty) {
        final parsedColor = _parseHtmlColor(colorStr);
        if (parsedColor != null) {
          setState(() {
            _adaptiveColor = parsedColor;
          });
          return;
        }
      }
      
      setState(() {
        _adaptiveColor = null;
      });
    } catch (e) {
      debugPrint('[BrowserScreen] Error al extraer theme-color: $e');
    }
  }

  String? _fallbackColorForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('github.com')) return '#0D1117';
    if (lower.contains('google.com')) return '#F8F9FA';
    if (lower.contains('youtube.com')) return '#FF0000';
    if (lower.contains('facebook.com')) return '#1877F2';
    if (lower.contains('twitter.com') || lower.contains('x.com')) return '#000000';
    if (lower.contains('wikipedia.org')) return '#F6F6F6';
    if (lower.contains('dulceapps.lovable.app')) return '#6C63FF';
    return null;
  }

  Color? _parseHtmlColor(String colorStr) {
    String clean = colorStr.trim().replaceAll('#', '');
    if (clean.startsWith('rgb')) {
      try {
        final RegExp rgbExp = RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)');
        final match = rgbExp.firstMatch(clean);
        if (match != null) {
          final r = int.parse(match.group(1)!);
          final g = int.parse(match.group(2)!);
          final b = int.parse(match.group(3)!);
          return Color.fromARGB(255, r, g, b);
        }
      } catch (_) {}
    } else {
      try {
        if (clean.length == 3) {
          clean = clean.split('').map((c) => c + c).join();
        }
        if (clean.length == 6) {
          return Color(int.parse('0xFF$clean'));
        } else if (clean.length == 8) {
          return Color(int.parse('0x$clean'));
        }
      } catch (_) {}
    }
    
    final basicColors = {
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'white': Colors.white,
      'black': Colors.black,
      'gray': Colors.grey,
      'orange': Colors.orange,
      'purple': Colors.purple,
    };
    return basicColors[clean.toLowerCase()];
  }

  // Metodos de navegacion
  void _navigate(String url) {
    String processedUrl = UrlUtils.processInput(url);

    // HTTPS upgrade silencioso: si el usuario escribe http:// lo intentamos
    // siempre con https:// primero. Edge/WebView2 mostrará su propio indicador
    // de "No seguro" si el servidor no soporta HTTPS, sin bloquear la UI.
    if (processedUrl.startsWith('http://')) {
      processedUrl = processedUrl.replaceFirst('http://', 'https://');
    }

    _doNavigate(processedUrl);
  }

  void _doNavigate(String url) {
    final String cleanUrl = UrlUtils.processInput(url);
    setState(() => _currentUrl = cleanUrl);
    final TabManager tabManager = context.read<TabManager>();
    _webViewController.resetForNewTab(cleanUrl);

    if (UrlUtils.isHomePage(cleanUrl)) {
      tabManager.updateTab(tabId: tabManager.activeTab.id, url: cleanUrl);
    } else {
      _webViewKey.currentState?.loadUrl(cleanUrl);
      tabManager.updateTab(tabId: tabManager.activeTab.id, url: cleanUrl);
    }

    context.read<MemoryManager>().onTabChanged();
    _webViewController.resetBlockedCount();
  }

  void _goBack() {
    if (_webViewController.pageInfo.canGoBack) {
      _webViewKey.currentState?.goBack();
    } else {
      final tabManager = context.read<TabManager>();
      if (!UrlUtils.isHomePage(tabManager.activeTab.url)) {
        _goHome();
      }
    }
  }

  void _goForward()   => _webViewKey.currentState?.goForward();
  void _reload()      => _webViewKey.currentState?.reload();
  void _stopLoading() => _webViewKey.currentState?.stopLoading();
  void _goHome()      => _navigate('about:dulcenav');

  void _handleNewTab(String url, {bool isIncognito = false}) {
    final TabManager tabs = context.read<TabManager>();
    final prev = tabs.activeTab;
    if (!prev.hasActiveMedia) {
      prev.controller?.pause();
    }
    tabs.addTab(url: url, isIncognito: isIncognito);
    _updateIncognitoScreenshotBlock();
    _navigate(url);
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    if (isCtrl && !isAlt && !isShift) {
      if (key == LogicalKeyboardKey.keyT) {
        _handleNewTab('about:dulcenav');
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyW) {
        _closeActiveTab();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyH) {
        _toggleHistory();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyD) {
        _onAddBookmark();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyJ) {
        _openDownloadsDrawer();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyR) {
        _reload();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyL) {
        _focusAddressBar();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add || key == LogicalKeyboardKey.numpadAdd) {
        _adjustZoom(0.1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
        _adjustZoom(-0.1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
        _resetZoom();
        return KeyEventResult.handled;
      }
    } else if (isCtrl && !isAlt && isShift) {
      if (key == LogicalKeyboardKey.keyR) {
        _reloadBypassingCache();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyN) {
        _handleNewTab('about:dulcenav', isIncognito: true);
        return KeyEventResult.handled;
      }
    } else if (!isCtrl && isAlt && !isShift) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _goBack();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _goForward();
        return KeyEventResult.handled;
      }
    }

    if (isCtrl && key == LogicalKeyboardKey.tab) {
      if (isShift) {
        _switchTabPrev();
      } else {
        _switchTabNext();
      }
      return KeyEventResult.handled;
    }

    if (!isCtrl && !isAlt && !isShift) {
      if (key == LogicalKeyboardKey.f5) {
        _reload();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.f6) {
        _focusAddressBar();
        return KeyEventResult.handled;
      }
    }

    if (isCtrl && key == LogicalKeyboardKey.f4) {
      _closeActiveTab();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _closeActiveTab() {
    final TabManager tabManager = context.read<TabManager>();
    if (tabManager.tabCount > 1) {
      final int index = tabManager.activeIndex;
      tabManager.closeTab(index);
      _updateIncognitoScreenshotBlock();
      _navigate(tabManager.activeTab.url);
    } else {
      _navigate('about:dulcenav');
      tabManager.updateTab(
        tabId: tabManager.activeTab.id,
        title: 'Nueva pestana',
        url: 'about:dulcenav',
      );
      _updateIncognitoScreenshotBlock();
    }
  }

  void _toggleHistory() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true && _leftDrawerType == 'history') {
      Navigator.of(context).pop();
    } else {
      _openHistoryDrawer();
    }
  }

  void _openHistoryDrawer() {
    final bool isIncognito = context.read<TabManager>().activeTab.isIncognito;
    if (isIncognito) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: DulceColors.warningYellow, size: 18),
              SizedBox(width: 8),
              Text(
                'No disponible en modo privado',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _leftDrawerType = 'history';
    });
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openDownloadsDrawer() {
    setState(() {
      _leftDrawerType = 'downloads';
    });
    _scaffoldKey.currentState?.openDrawer();
  }

  void _onWebMessageReceived(dynamic message) {
    if (message is String) {
      try {
        final data = jsonDecode(message);
        if (data is Map) {
          if (data['type'] == 'download') {
            final url = data['url']?.toString() ?? '';
            final fileName = data['fileName']?.toString() ?? '';
            if (url.isNotEmpty) {
              _initiateDownload(url, fileName: fileName);
            }
          } else if (data['type'] == 'mediaState') {
            final playing = data['playing'] as bool? ?? false;
            final tabManager = context.read<TabManager>();
            tabManager.setMediaActive(tabManager.activeTab.id, playing);
          } else if (data['type'] == 'loginDetected') {
            final tabManager = context.read<TabManager>();
            if (!tabManager.activeTab.isIncognito) {
              final domain = data['domain']?.toString() ?? '';
              final username = data['username']?.toString() ?? '';
              final password = data['password']?.toString() ?? '';
              if (domain.isNotEmpty && username.isNotEmpty && password.isNotEmpty) {
                if (!StorageService.instance.autofillExcludedDomains.contains(domain)) {
                  _showSavePasswordDialog(domain, username, password);
                }
              }
            }
          } else if (data['type'] == 'autofill_detected') {
            final tabManager = context.read<TabManager>();
            if (StorageService.instance.autofillEnabled) {
              final bool disableInIncognito = StorageService.instance.autofillDisableInIncognito;
              if (tabManager.activeTab.isIncognito && disableInIncognito) {
                return;
              }
              final domain = data['domain']?.toString() ?? '';
              if (StorageService.instance.autofillExcludedDomains.contains(domain)) {
                return;
              }
              final rect = data['rect'] as Map?;
              if (domain.isNotEmpty && rect != null) {
                final entries = PasswordService.instance.getEntriesForDomain(domain);
                if (entries.isNotEmpty) {
                  setState(() {
                    _showAutofill = true;
                    _autofillX = (rect['x'] as num? ?? 0).toDouble();
                    _autofillY = (rect['y'] as num? ?? 0).toDouble();
                    _autofillHeight = (rect['height'] as num? ?? 0).toDouble();
                    _autofillDomain = domain;
                    _autofillEntries = entries;
                  });
                }
              }
            }
          } else if (data['type'] == 'autofill_dismiss') {
            setState(() {
              _showAutofill = false;
            });
          } else if (data['type'] == 'contextmenu') {
            final x = data['x'] as num? ?? 0;
            final y = data['y'] as num? ?? 0;
            final elementType = data['elementType']?.toString() ?? 'empty';
            final linkUrl = data['linkUrl']?.toString() ?? '';
            final imageUrl = data['imageUrl']?.toString() ?? '';
            final selectedText = data['selectedText']?.toString() ?? '';
            final isEditable = data['isEditable'] as bool? ?? false;

            _showCustomContextMenu(
              x.toDouble(),
              y.toDouble(),
              elementType,
              linkUrl,
              imageUrl,
              selectedText,
              isEditable,
            );
          }
        }
      } catch (_) {}
    }
  }

  void _showCustomContextMenu(
    double x,
    double y,
    String elementType,
    String linkUrl,
    String imageUrl,
    String selectedText,
    bool isEditable,
  ) {
    if (!StorageService.instance.contextMenuEnabled) return;

    final RenderBox? renderBox = _webViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset localOffset = Offset(x, y);
    final Offset globalOffset = renderBox.localToGlobal(localOffset);
    final RelativeRect position = RelativeRect.fromLTRB(
      globalOffset.dx,
      globalOffset.dy,
      globalOffset.dx + 1,
      globalOffset.dy + 1,
    );

    final List<PopupMenuEntry<String>> items = [];

    if (elementType == 'link') {
      items.addAll([
        _buildContextMenuItem(Icon(Icons.tab_rounded), 'Abrir en nueva pestana', 'open_new_tab'),
        _buildContextMenuItem(Icon(Icons.private_connectivity_rounded), 'Abrir en pestana de incognito', 'open_incognito_tab'),
        _buildContextMenuItem(Icon(Icons.content_copy_rounded), 'Copiar direccion de enlace', 'copy_link_address'),
        _buildContextMenuItem(Icon(Icons.download_rounded), 'Guardar enlace como...', 'save_link'),
        _buildContextMenuItem(Icon(Icons.share_rounded), 'Compartir enlace', 'share_link'),
        _buildContextMenuItem(Icon(Icons.bookmark_add_rounded), 'Anadir a favoritos', 'add_bookmark'),
      ]);
    } else if (elementType == 'image') {
      items.addAll([
        _buildContextMenuItem(Icon(Icons.open_in_new_rounded), 'Abrir imagen en nueva pestana', 'open_image_tab'),
        _buildContextMenuItem(Icon(Icons.link_rounded), 'Copiar direccion de imagen', 'copy_image_address'),
        _buildContextMenuItem(Icon(Icons.download_rounded), 'Guardar imagen como...', 'save_image'),
        _buildContextMenuItem(Icon(Icons.image_rounded), 'Copiar imagen al portapapeles', 'copy_image'),
      ]);
    } else if (elementType == 'selection') {
      items.addAll([
        _buildContextMenuItem(Icon(Icons.content_copy_rounded), 'Copiar', 'copy_selection'),
        if (isEditable) ...[
          _buildContextMenuItem(Icon(Icons.content_cut_rounded), 'Cortar', 'cut_selection'),
          _buildContextMenuItem(Icon(Icons.content_paste_rounded), 'Pegar', 'paste_selection'),
        ],
        _buildContextMenuItem(Icon(Icons.search_rounded), 'Buscar en internet', 'search_selection'),
        _buildContextMenuItem(Icon(Icons.travel_explore_rounded), 'Buscar en Google', 'search_google'),
        _buildContextMenuItem(Icon(Icons.g_translate_rounded), 'Traducir seleccion', 'translate_selection'),
        _buildContextMenuItem(Icon(Icons.psychology_rounded), 'Enviar a DulceMind IA', 'send_to_ai'),
      ]);
    } else if (elementType == 'input') {
      items.addAll([
        _buildContextMenuItem(Icon(Icons.content_paste_rounded), 'Pegar', 'paste_selection'),
        _buildContextMenuItem(Icon(Icons.select_all_rounded), 'Seleccionar todo', 'select_all'),
      ]);
    } else {
      items.addAll([
        _buildContextMenuItem(Icon(Icons.arrow_back_rounded), 'Volver atras', 'go_back'),
        _buildContextMenuItem(Icon(Icons.arrow_forward_rounded), 'Ir adelante', 'go_forward'),
        _buildContextMenuItem(Icon(Icons.refresh_rounded), 'Recargar pagina', 'reload_page'),
        _buildContextMenuItem(Icon(Icons.translate_rounded), 'Traducir pagina', 'translate_page'),
        _buildContextMenuItem(Icon(Icons.code_rounded), 'Ver codigo fuente', 'view_source'),
        _buildContextMenuItem(Icon(Icons.security_rounded), 'Ver informacion de seguridad', 'view_security'),
        _buildContextMenuItem(Icon(Icons.developer_mode_rounded), 'Inspeccionar elemento', 'inspect_element'),
      ]);
    }

    showMenu<String>(
      context: context,
      position: position,
      items: items,
      color: const Color(0xFF1E1E2E).withOpacity(0.92),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: DulceColors.primary.withOpacity(0.35),
          width: 1.2,
        ),
      ),
    ).then((value) {
      if (value == null) return;
      _handleContextMenuAction(value, linkUrl, imageUrl, selectedText);
    });
  }

  PopupMenuItem<String> _buildContextMenuItem(Widget icon, String label, String value) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme(
            data: IconThemeData(color: Colors.white70, size: 16),
            child: icon,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _handleContextMenuAction(
    String action,
    String linkUrl,
    String imageUrl,
    String selectedText,
  ) {
    final tabManager = context.read<TabManager>();

    switch (action) {
      case 'open_new_tab':
        _handleNewTab(linkUrl);
        break;
      case 'open_incognito_tab':
        _handleNewTab(linkUrl, isIncognito: true);
        break;
      case 'copy_link_address':
        Clipboard.setData(ClipboardData(text: linkUrl)).then((_) {
          _showToast('Direccion de enlace copiada');
        });
        break;
      case 'save_link':
        final fileName = linkUrl.split('?')[0].split('/').last;
        _initiateDownload(linkUrl, fileName: fileName.isEmpty ? 'enlace' : fileName);
        break;
      case 'share_link':
        Clipboard.setData(ClipboardData(text: linkUrl)).then((_) {
          _showToast('Enlace copiado para compartir');
        });
        break;
      case 'add_bookmark':
        StorageService.instance.addBookmarkWithTitle(UrlUtils.getDomain(linkUrl), linkUrl).then((_) {
          _showToast('Enlace guardado en Favoritos');
        });
        break;

      case 'open_image_tab':
        _handleNewTab(imageUrl);
        break;
      case 'copy_image_address':
        Clipboard.setData(ClipboardData(text: imageUrl)).then((_) {
          _showToast('Direccion de imagen copiada');
        });
        break;
      case 'save_image':
        final fileName = imageUrl.split('?')[0].split('/').last;
        _initiateDownload(imageUrl, fileName: fileName.isEmpty ? 'imagen.png' : fileName);
        break;
      case 'copy_image':
        Clipboard.setData(ClipboardData(text: imageUrl)).then((_) {
          _showToast('Direccion de la imagen copiada al portapapeles');
        });
        break;

      case 'copy_selection':
        Clipboard.setData(ClipboardData(text: selectedText)).then((_) {
          _showToast('Texto copiado');
        });
        break;
      case 'cut_selection':
        Clipboard.setData(ClipboardData(text: selectedText)).then((_) {
          _webViewKey.currentState?.executeScript("document.execCommand('delete');");
          _showToast('Texto cortado');
        });
        break;
      case 'paste_selection':
        Clipboard.getData(Clipboard.kTextPlain).then((data) {
          final text = data?.text ?? '';
          if (text.isNotEmpty) {
            final escaped = text.replaceAll("'", "\\'").replaceAll("\n", "\\n");
            _webViewKey.currentState?.executeScript("document.activeElement.value += '$escaped';");
          }
        });
        break;
      case 'search_selection':
        final query = SearchOptimizer.optimize(selectedText);
        final engine = StorageService.instance.searchEngine;
        final url = SearchOptimizer.buildSearchUrl(query, engine);
        _handleNewTab(url);
        break;
      case 'search_google':
        final query = SearchOptimizer.optimize(selectedText);
        final url = SearchOptimizer.buildSearchUrl(query, 'https://www.google.com/search?q=');
        _handleNewTab(url);
        break;
      case 'translate_selection':
        final url = 'https://translate.google.com/?sl=auto&tl=es&text=${Uri.encodeComponent(selectedText)}';
        _handleNewTab(url);
        break;
      case 'send_to_ai':
        final ai = context.read<DulceMindService>();
        _scaffoldKey.currentState?.openEndDrawer();
        ai.askQuestion('Analizar o explicar: "$selectedText"', tabManager.activeTab.title, selectedText);
        break;

      case 'select_all':
        _webViewKey.currentState?.executeScript("document.activeElement.select();");
        break;

      case 'go_back':
        _goBack();
        break;
      case 'go_forward':
        _goForward();
        break;
      case 'reload_page':
        _reload();
        break;
      case 'translate_page':
        final url = 'https://translate.google.com/translate?sl=auto&tl=es&u=${Uri.encodeComponent(_currentUrl)}';
        _handleNewTab(url);
        break;
      case 'view_source':
        _webViewKey.currentState?.getPageHtml().then((html) {
          _showSourceCodeDialog(html);
        });
        break;
      case 'view_security':
        _onSecurityInfo();
        break;
      case 'inspect_element':
        _webViewKey.currentState?.openDevTools();
        break;
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  void _showSavePasswordDialog(String domain, String username, String password) {
    if (!mounted) return;
    
    final entries = PasswordService.instance.getEntriesForDomain(domain);
    final exists = entries.any((entry) => entry.username == username && entry.password == password);
    if (exists) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white10),
          ),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                '¿Guardar contraseña?',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Deseas guardar la contraseña para "$username" en $domain?',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Se guardara de forma cifrada (AES-256) en tu Administrador de Credenciales de Windows.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white30,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Nunca', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await PasswordService.instance.saveCredentials(domain, username, password);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _showToast('Contraseña guardada de forma segura');
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _showSourceCodeDialog(String html) {
    showDialog(
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
              Icon(Icons.code_rounded, color: DulceColors.primary),
              const SizedBox(width: 10),
              Text(
                'Codigo Fuente de la Pagina',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: html)).then((_) {
                    Navigator.of(ctx).pop();
                    _showToast('Codigo fuente copiado al portapapeles');
                  });
                },
                tooltip: 'Copiar todo',
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  html,
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cerrar', style: TextStyle(color: Colors.white60)),
            ),
          ],
        );
      },
    );
  }

  void _showEnableAiDialog(DulceMindService ai) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: DulceColors.primary.withOpacity(0.35),
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.psychology_rounded, color: DulceColors.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Activar DulceMind IA',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Deseas activar el asistente inteligente DulceMind IA?',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'DulceMind funciona 100% de forma local, protegiendo tu privacidad sin enviar datos personales a servidores externos. Te ayudara a resumir paginas, responder preguntas, simular reservas y organizar tu agenda.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Ahora no', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                ai.toggleEnabled(true);
                _showToast('Activando DulceMind IA. Revisa su estado en Ajustes.');
              },
              child: Text('Activar Asistente'),
            ),
          ],
        );
      },
    );
  }

  void _initiateDownload(String url, {String? fileName}) {
    final lowerName = (fileName ?? '').toLowerCase();
    final isDangerous = lowerName.endsWith('.exe') ||
        lowerName.endsWith('.msi') ||
        lowerName.endsWith('.bat') ||
        lowerName.endsWith('.dll');

    if (isDangerous) {
      _showDangerousDownloadWarning(url, fileName ?? '');
    } else if (StorageService.instance.askDownloadLocation) {
      _showConfirmDownloadDialog(url, fileName ?? '');
    } else {
      context.read<DownloadManager>().startDownload(url, customFileName: fileName);
      _showDownloadStartedSnackBar(fileName ?? 'archivo');
    }
  }

  void _showDangerousDownloadWarning(String url, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C0F14), // Dark red background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text(
                '¡Descarga Peligrosa!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El archivo "$fileName" puede dañar tu computadora.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Los archivos ejecutables (.exe, .msi, .bat, .dll) pueden contener virus o software malicioso que robe tu informacion personal o dañe el sistema.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '¿Deseas descargar este archivo de todos modos?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar (Recomendado)', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (StorageService.instance.askDownloadLocation) {
                  _showConfirmDownloadDialog(url, fileName);
                } else {
                  context.read<DownloadManager>().startDownload(url, customFileName: fileName);
                  _showDownloadStartedSnackBar(fileName);
                }
              },
              child: Text('Descargar de todos modos'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDownloadDialog(String url, String defaultFileName) {
    final controller = TextEditingController(text: defaultFileName);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white12),
          ),
          title: Text(
            'Confirmar descarga',
            style: TextStyle(
              fontFamily: 'Outfit',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nombre del archivo:',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: DulceColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: DulceColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Carpeta de destino:',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: DulceColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                StorageService.instance.downloadPath,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: DulceColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  context.read<DownloadManager>().startDownload(url, customFileName: newName);
                  Navigator.of(ctx).pop();
                  _showDownloadStartedSnackBar(newName);
                }
              },
              child: Text('Descargar'),
            ),
          ],
        );
      },
    );
  }

  void _showDownloadStartedSnackBar(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.downloading_rounded, color: DulceColors.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Iniciando descarga: $fileName',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDownloadCompletedSnackBar(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: DulceColors.safeGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Descarga finalizada: $fileName',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _switchTabNext() {
    final TabManager tabManager = context.read<TabManager>();
    if (tabManager.tabCount <= 1) return;
    final nextIdx = (tabManager.activeIndex + 1) % tabManager.tabCount;
    tabManager.switchTo(nextIdx);
    setState(() {
      _currentUrl = tabManager.activeTab.url;
      _siteStatus = _classifySite(_currentUrl);
    });
  }

  void _switchTabPrev() {
    final TabManager tabManager = context.read<TabManager>();
    if (tabManager.tabCount <= 1) return;
    final prevIdx = (tabManager.activeIndex - 1 + tabManager.tabCount) % tabManager.tabCount;
    tabManager.switchTo(prevIdx);
    setState(() {
      _currentUrl = tabManager.activeTab.url;
      _siteStatus = _classifySite(_currentUrl);
    });
  }

  void _focusAddressBar() {
    _addressBarFocusNode.requestFocus();
  }

  void _reloadBypassingCache() {
    _webViewKey.currentState?.reloadBypassingCache();
  }

  void _adjustZoom(double delta) {
    if (UrlUtils.isHomePage(_currentUrl)) return;
    setState(() {
      _zoomFactor = (_zoomFactor + delta).clamp(0.5, 3.0);
    });
    _webViewKey.currentState?.setZoomFactor(_zoomFactor);
    _showZoomSnackBar();
  }

  void _resetZoom() {
    if (UrlUtils.isHomePage(_currentUrl)) return;
    setState(() {
      _zoomFactor = 1.0;
    });
    _webViewKey.currentState?.setZoomFactor(1.0);
    _showZoomSnackBar();
  }

  void _showZoomSnackBar() {
    final percent = (_zoomFactor * 100).round();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.zoom_in_rounded, color: DulceColors.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              'Zoom: $percent%',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        width: 150,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TabManager tabManager = context.watch<TabManager>();

    final mainWidget = Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        return _handleKeyEvent(event);
      },
      child: ListenableBuilder(
        listenable: _webViewController,
        builder: (BuildContext ctx, Widget? child) {
          return Scaffold(
            key: _scaffoldKey,
            resizeToAvoidBottomInset: false,
            backgroundColor: DulceColors.background,
            drawer: _leftDrawerType == 'history'
                ? _HistoryDrawer(
                    onNavigate: _navigate,
                    onClose: () => Navigator.of(context).pop(),
                  )
                : DulceDownloadsDrawer(
                    onClose: () => Navigator.of(context).pop(),
                  ),
            endDrawer: _DulceMindDrawer(
              activeUrl: _currentUrl,
              activeTitle: tabManager.activeTab.title,
              getPageText: () async {
                return await _webViewKey.currentState?.getPageText() ?? '';
              },
            ),
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  // Barra de pestanas (ARRIBA)
                  TabBarWidget(
                    tabManager: tabManager,
                    adaptiveColor: _adaptiveColor,
                    onNewTab: () => _handleNewTab('about:dulcenav'),
                    onNewIncognitoTab: () => _handleNewTab('about:dulcenav', isIncognito: true),
                    onTabSelected: (int index) {
                      final DulceTab prev = tabManager.activeTab;
                      tabManager.switchTo(index);
                      final DulceTab next = tabManager.activeTab;
                      if (prev.id != next.id) {
                        // 1. Pestana saliente: si NO tiene media -> pause() para ahorrar memoria
                        if (!prev.hasActiveMedia) {
                          prev.controller?.pause();
                        }

                        // 2. Pestana entrante: resume si tiene active media
                        if (next.hasActiveMedia) {
                          next.controller?.resume();
                        }
                        setState(() {
                          _currentUrl = next.url;
                          _siteStatus = _classifySite(next.url);
                          // Reset adaptive color when switching tabs, it will re-extract
                          _adaptiveColor = null;
                        });
                        _extractAndApplyThemeColor();
                        _updateIncognitoScreenshotBlock();
                      }
                    },
                    onTabClosed: (int index) {
                      tabManager.closeTab(index);
                      final DulceTab next = tabManager.activeTab;
                      if (next.hasActiveMedia) {
                        next.controller?.resume();
                      }
                      setState(() {
                        _currentUrl = next.url;
                        _siteStatus = _classifySite(next.url);
                        _adaptiveColor = null;
                      });
                      _extractAndApplyThemeColor();
                      _updateIncognitoScreenshotBlock();
                    },
                  ),

                  // Barra superior: URL + seguridad
                  _BrowserTopBar(
                    currentUrl: _currentUrl,
                    isLoading: _webViewController.isLoading,
                    siteStatus: _siteStatus,
                    blockedCount: _webViewController.blockedCount,
                    onNavigate: _navigate,
                    onRefresh: _reload,
                    onStop: _stopLoading,
                    onBrainPressed: () {
                      final ai = context.read<DulceMindService>();
                      if (ai.isEnabled && ai.isReady) {
                        _scaffoldKey.currentState?.openEndDrawer();
                      } else {
                        _showEnableAiDialog(ai);
                      }
                    },
                    onDownloadsPressed: _openDownloadsDrawer,
                    addressBarFocusNode: _addressBarFocusNode,
                    isIncognito: tabManager.activeTab.isIncognito,
                    adaptiveColor: _adaptiveColor,
                  ),

                // Barra de progreso de carga con destello de luz corriendo
                if (_webViewController.isLoading)
                  DulceProgressBar(
                    value: _webViewController.loadProgress > 0
                        ? _webViewController.loadProgress
                        : 0.15,
                  ),

                // Barra de favoritos
                if (StorageService.instance.showBookmarksBar &&
                    !tabManager.activeTab.isIncognito)
                  BookmarksBar(
                    onNavigate: _navigate,
                    onNewTab: (url, {isIncognito = false}) =>
                        _handleNewTab(url, isIncognito: isIncognito),
                  ),

                // Separador
                Container(height: 1, color: DulceColors.border),

                // Area del WebView
                Expanded(child: _buildWebViewArea(tabManager)),

                // Barra de navegacion inferior
                DulceNavBar(
                  canGoBack: _webViewController.pageInfo.canGoBack || !UrlUtils.isHomePage(tabManager.activeTab.url),
                  canGoForward: _webViewController.pageInfo.canGoForward,
                  tabCount: tabManager.tabCount,
                  onBack: _goBack,
                  onForward: _goForward,
                  onHome: _goHome,
                  onTabs: _showTabsPanel,
                  onMenu: _showMenu,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  return PopScope(
    canPop: false,
    onPopInvoked: (bool didPop) async {
      if (didPop) return;
      if (_webViewController.pageInfo.canGoBack) {
        _goBack();
        return;
      }

      if (!mounted) return;
      final bool? exitConfirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF13131F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white10),
          ),
          title: const Text(
            '¿Salir de DulceNav?',
            style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '¿Seguro que deseas salir de la aplicacion?',
            style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );

      if (exitConfirmed == true) {
        SystemNavigator.pop();
      }
    },
    child: mainWidget,
  );
}

  Widget _buildWebViewArea(TabManager tabManager) {
    final DulceTab activeTab = tabManager.activeTab;

    if (tabManager.tabs.isEmpty) return const SizedBox.shrink();

    final int activeIndex = tabManager.tabs.indexWhere((t) => t.id == activeTab.id);

    return IndexedStack(
      index: activeIndex != -1 ? activeIndex : 0,
      children: tabManager.tabs.map((tab) {
        final bool isActive = (tab.id == activeTab.id);
        Widget tabWidget;

        final isHostBypassed = _isHostBypassed(tab.url);
        final siteStatus = (tab.id == activeTab.id) ? _siteStatus : _classifySite(tab.url);
        final isDanger = siteStatus == SiteStatus.danger && !isHostBypassed;

        if (tab.isIncognito && !isActive && tab.isHibernated) {
          tabWidget = const SizedBox.shrink();
        } else if (tab.isHibernated) {
          tabWidget = _HibernatedPlaceholder(
            key: ValueKey<String>('hibernated_${tab.id}'),
            title: tab.title,
            onWake: () {
              tabManager.switchTo(tabManager.tabs.indexOf(tab));
              _navigate(tab.url);
            },
          );
        } else if (isDanger) {
          tabWidget = _buildDangerBlockScreen(tab.url);
        } else if (UrlUtils.isHomePage(tab.url)) {
          tabWidget = HomeScreen(
            key: ValueKey<String>('home_${tab.id}'),
            onNavigate: _navigate,
            onNewTabWithUrl: _handleNewTab,
            isIncognito: tab.isIncognito,
          );
        } else {
          final key = _webViewKeys.putIfAbsent(tab.id, () => GlobalKey<DulceWebViewState>());
          tabWidget = Stack(
            key: ValueKey<String>('webview_${tab.id}'),
            children: [
              DulceWebView(
                key: key,
                tabId: tab.id,
                initialUrl: tab.url,
                isIncognito: tab.isIncognito,
                onUrlChanged: (url) {
                  if (tab.id == tabManager.activeTab.id) _onUrlChanged(url);
                },
                onTitleChanged: (title) {
                  if (tab.id == tabManager.activeTab.id) _onTitleChanged(title);
                },
                onLoadingChanged: (loading) {
                  if (tab.id == tabManager.activeTab.id) _onLoadingChanged(loading);
                },
                onRequestBlocked: (count) {
                  if (tab.id == tabManager.activeTab.id) _webViewController.onRequestBlocked();
                },
                onWebMessageReceived: (msg) {
                  if (tab.id == tabManager.activeTab.id) _onWebMessageReceived(msg);
                },
                onReceivedError: (error) {
                  if (tab.id == tabManager.activeTab.id) {
                    _webViewController.onPageError(error);
                  }
                },
              ),
              if (isActive && _webViewController.loadState == WebViewLoadState.error)
                _ErrorOverlay(
                  errorMessage: _webViewController.errorMessage ?? 'Error de conexion.',
                  onRetry: _reload,
                  onGoHome: _goHome,
                ),
              if (isActive && _showAutofill && _autofillEntries.isNotEmpty)
                Positioned(
                  left: (() {
                    final screenWidth = MediaQuery.of(context).size.width;
                    if (_autofillX + 280 > screenWidth) {
                      return screenWidth - 290.0;
                    }
                    return _autofillX;
                  })(),
                  top: (() {
                    double y = _autofillY + _autofillHeight + 4;
                    final screenHeight = MediaQuery.of(context).size.height;
                    if (y + 160 > screenHeight) {
                      y = _autofillY - 150 - 4;
                      if (y < 0) y = 10.0;
                    }
                    return y;
                  })(),
                  width: 280,
                  child: AutofillPopup(
                    entries: _autofillEntries,
                    domain: _autofillDomain,
                    onSelect: (entry) async {
                      final verified = await PasswordService.instance.requestAccess(
                        context,
                        'Autocompletar credenciales en $_autofillDomain',
                      );
                      if (verified) {
                        final plainPassword = await PasswordService.instance.decryptText(entry.password);
                        if (plainPassword != null) {
                          _webViewKey.currentState?.autofillCredentials(entry.username, plainPassword);
                        }
                      }
                      setState(() {
                        _showAutofill = false;
                      });
                    },
                    onDismiss: () {
                      setState(() {
                        _showAutofill = false;
                      });
                    },
                    onExcludeSite: () async {
                      await StorageService.instance.addAutofillExcludedDomain(_autofillDomain);
                      setState(() {
                        _showAutofill = false;
                      });
                      _showToast('Sitio excluido de autocompletado');
                    },
                  ),
                ),
              if (isActive)
                _LoadingOverlay(
                  isLoading: _webViewController.isLoading,
                ),
            ],
          );
        }

        return KeyedSubtree(
          key: ValueKey<String>(tab.id),
          child: tabWidget,
        );
      }).toList(),
    );
  }

  bool _isHostBypassed(String url) {
    try {
      final host = Uri.parse(url).host;
      return _bypassedHosts.contains(host);
    } catch (_) {
      return false;
    }
  }

  Widget _buildDangerBlockScreen(String url) {
    String host = url;
    try {
      host = Uri.parse(url).host;
    } catch (_) {}

    return Container(
      color: const Color(0xFF1A0A0D), // Dark red background
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: Icon(
                  Icons.gpp_bad_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Sitio no seguro detectado!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'DulceShield Pro ha bloqueado el acceso a $host.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Este sitio puede intentar:',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.bug_report_rounded, color: Colors.redAccent, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('Instalar software malicioso (malware/virus).', style: TextStyle(color: Colors.white70, fontSize: 12))),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.password_rounded, color: Colors.redAccent, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('Robar tus contraseñas, mensajes o tarjetas de crédito.', style: TextStyle(color: Colors.white70, fontSize: 12))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.arrow_back_rounded),
                    label: Text('Volver a salvo'),
                    onPressed: () {
                      _goBack();
                    },
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        try {
                          final host = Uri.parse(url).host;
                          if (host.isNotEmpty) {
                            _bypassedHosts.add(host);
                          }
                        } catch (_) {}
                      });
                    },
                    child: Text(
                      'Proceder de todos modos (No recomendado)',
                      style: TextStyle(color: Colors.redAccent, decoration: TextDecoration.underline, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Panel de pestanas (bottom sheet)
  void _showTabsPanel() {
    final TabManager tabs = context.read<TabManager>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DulceColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return _TabsBottomSheet(
          tabManager: tabs,
          onTabSelected: (int index) {
            final DulceTab prev = tabs.activeTab;
            tabs.switchTo(index);
            final DulceTab next = tabs.activeTab;
            Navigator.of(context).pop();

            if (prev.id != next.id) {
              if (!prev.hasActiveMedia) {
                prev.controller?.pause();
              }
              if (next.hasActiveMedia) {
                next.controller?.resume();
              }
              setState(() {
                _currentUrl = next.url;
                _siteStatus = _classifySite(next.url);
              });
            }
          },
          onTabClosed: (int index) {
            tabs.closeTab(index);
            if (context.mounted) {
              final DulceTab next = tabs.activeTab;
              if (next.hasActiveMedia) {
                next.controller?.resume();
              }
              setState(() {
                _currentUrl = next.url;
                _siteStatus = _classifySite(next.url);
              });
            }
          },
          onNewTab: () {
            tabs.addTab();
            Navigator.of(context).pop();
            _navigate('about:dulcenav');
          },
        );
      },
    );
  }

  // Menu principal
  void _showMenu() {
    final bool isIncognito = context.read<TabManager>().activeTab.isIncognito;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DulceColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MainMenu(
        currentUrl: _currentUrl,
        isIncognito: isIncognito,
        onAddBookmark: _onAddBookmark,
        onShare: _onShare,
        onDownload: _onDownload,
        onSecurityInfo: _onSecurityInfo,
        onAbout: _onAbout,
        onOpenHistory: _openHistoryDrawer,
        onOpenDownloads: _openDownloadsDrawer,
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SettingsScreen(),
            ),
          );
        },
        onOpenIncognito: () {
          _handleNewTab('about:dulcenav', isIncognito: true);
        },
      ),
    );
  }

  void _onAddBookmark() async {
    final bool isIncognito = context.read<TabManager>().activeTab.isIncognito;
    if (isIncognito) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: DulceColors.warningYellow, size: 18),
              SizedBox(width: 8),
              Text(
                'No disponible en modo privado',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final String title = context.read<TabManager>().activeTab.title;
    final String url = _currentUrl;
    await StorageService.instance.addBookmarkWithTitle(title, url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: DulceColors.safeGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Guardado en Favoritos',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onShare() {
    Clipboard.setData(ClipboardData(text: _currentUrl)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.link_rounded, color: DulceColors.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Enlace copiado al portapapeles',
                  style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E2E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _onDownload() async {
    if (UrlUtils.isHomePage(_currentUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede descargar la pagina de inicio.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(
              'Descargando pagina...',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 800),
      ),
    );

    try {
      final htmlContent = await _webViewKey.currentState?.getPageHtml() ?? '';
      if (htmlContent.isEmpty) {
        throw Exception('El contenido HTML esta vacio');
      }

      final String rawTitle = context.read<TabManager>().activeTab.title;
      final String safeTitle = (rawTitle.isEmpty ? 'Pagina' : rawTitle)
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final String fileName = '$safeTitle.html';

      final dir = Directory(StorageService.instance.downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}$fileName');
      await file.writeAsString(htmlContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: DulceColors.safeGreen, size: 18),
                SizedBox(width: 8),
                Text(
                  'Guardado correctamente',
                  style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E2E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Download] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar la pagina: $e'),
            backgroundColor: DulceColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onSecurityInfo() {
    final isHttps = _currentUrl.startsWith('https://');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF181828).withOpacity(0.85),
                border: Border(
                  top: BorderSide(
                    color: DulceColors.primary.withOpacity(0.35),
                    width: 1.2,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isHttps ? Icons.lock_rounded : Icons.lock_open_rounded,
                        color: isHttps ? DulceColors.safeGreen : DulceColors.dangerRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isHttps ? 'Conexion segura (SSL)' : 'Conexion no segura (HTTP)',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isHttps ? DulceColors.safeGreen : DulceColors.dangerRed,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  _buildSecurityRow(
                    Icon(Icons.verified_user_rounded),
                    'Certificado SSL:',
                    isHttps ? 'Valido y activo' : 'Invalido o ausente',
                    isHttps ? DulceColors.safeGreen : DulceColors.dangerRed,
                  ),
                  const SizedBox(height: 12),
                  _buildSecurityRow(
                    Icon(Icons.block_rounded),
                    'Rastreadores bloqueados:',
                    '${_webViewController.blockedCount} elementos interceptados',
                    DulceColors.accent,
                  ),
                  const SizedBox(height: 12),
                  _buildSecurityRow(
                    Icon(Icons.shield_outlined),
                    'Permisos del sitio:',
                    'Camara: Desactivada | Microfono: Desactivado | Ubicacion: Desactivada',
                    DulceColors.textSecondary,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DulceColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Entendido'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecurityRow(Widget icon, String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTheme(
          data: IconThemeData(size: 16, color: DulceColors.textSecondary),
          child: icon,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: DulceColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onAbout() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white12),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: DulceColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.travel_explore_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Acerca de DulceNav',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DulceNav - Navegador Privado',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version: v1.8.1',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: DulceColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Desarrollado con tecnologia Flutter y WebView2.\n'
                'Navegacion rapida, segura y 100% privada.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: DulceColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

// ==============================================================
// Barra superior del navegador
// ==============================================================
class _BrowserTopBar extends StatelessWidget {
  final String currentUrl;
  final bool isLoading;
  final SiteStatus siteStatus;
  final int blockedCount;
  final Function(String) onNavigate;
  final VoidCallback onRefresh;
  final VoidCallback onStop;
  final VoidCallback? onBrainPressed;
  final VoidCallback onDownloadsPressed;
  final FocusNode? addressBarFocusNode;
  final bool isIncognito;
  final Color? adaptiveColor;

  const _BrowserTopBar({
    required this.currentUrl,
    required this.isLoading,
    required this.siteStatus,
    required this.blockedCount,
    required this.onNavigate,
    required this.onRefresh,
    required this.onStop,
    required this.onDownloadsPressed,
    this.onBrainPressed,
    this.addressBarFocusNode,
    this.isIncognito = false,
    this.adaptiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final perf = context.watch<PerformanceService>();
    final isGameActive = perf.isGameModeActive;

    final hasAdaptive = StorageService.instance.adaptiveThemeEnabled && adaptiveColor != null && !isIncognito;
    final isDarkColor = adaptiveColor == null || ThemeData.estimateBrightnessForColor(adaptiveColor!) == Brightness.dark;
    final contentColor = isDarkColor ? Colors.white : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: hasAdaptive ? adaptiveColor : null,
        gradient: hasAdaptive
            ? null
            : (isIncognito
                ? const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF1E1E2E), Color(0xFF151522)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )),
        border: Border(
          top: BorderSide(
            color: contentColor.withOpacity(0.12), // specular top edge highlight/shine
            width: 1.0,
          ),
          bottom: BorderSide(
            color: DulceColors.border,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: <Widget>[
                SecurityBadge(
                  status: siteStatus,
                  blockedCount: blockedCount,
                ),
                if (isIncognito) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00D4FF).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\u{1F575}',
                          style: TextStyle(fontSize: 12),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Incognito',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D4FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (!UrlUtils.isHomePage(currentUrl))
                  Text(
                    UrlUtils.getDomain(currentUrl),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: DulceColors.textDisabled,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DulceAddressBar(
                  currentUrl: currentUrl,
                  isLoading: isLoading,
                  onNavigate: onNavigate,
                  onRefresh: onRefresh,
                  onStop: onStop,
                  focusNode: addressBarFocusNode,
                ),
              ),
              _DownloadButtonWithBadge(
                onPressed: onDownloadsPressed,
                isIncognito: isIncognito,
              ),
               IconButton(
                icon: Icon(
                  Icons.sports_esports_rounded,
                  color: isGameActive
                      ? const Color(0xFF00FF87)
                      : (isIncognito ? const Color(0xFF00D4FF) : Colors.white),
                  size: 20,
                ),
                onPressed: () {
                  perf.setGameMode(!isGameActive);
                },
                tooltip: 'Modo Rendimiento',
              ),
              if (!context.watch<DulceMindService>().isHideFeature)
                IconButton(
                  icon: Icon(
                    Icons.psychology_rounded,
                    color: context.watch<DulceMindService>().isModelDownloaded
                        ? const Color(0xFF00D4FF)
                        : Colors.grey,
                    size: 20,
                  ),
                  onPressed: onBrainPressed,
                  tooltip: 'DulceMind IA Local',
                ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadButtonWithBadge extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isIncognito;

  const _DownloadButtonWithBadge({required this.onPressed, this.isIncognito = false});

  @override
  Widget build(BuildContext context) {
    final downloadManager = context.watch<DownloadManager>();
    final activeCount = downloadManager.activeDownloadsCount;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.download_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: onPressed,
          tooltip: 'Descargas',
        ),
        if (activeCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isIncognito ? const Color(0xFF00D4FF) : DulceColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isIncognito ? const Color(0xFF1E293B) : const Color(0xFF1E1E2E),
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                '$activeCount',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// _HomeContent has been removed since we now render the full HomeScreen inline.

// ==============================================================
// Placeholder de pestana hibernada
// ==============================================================
class _HibernatedPlaceholder extends StatelessWidget {
  final String title;
  final VoidCallback onWake;

  const _HibernatedPlaceholder({
    super.key,
    required this.title,
    required this.onWake,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.bedtime_rounded,
            size: 48,
            color: DulceColors.primary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Pestana en hibernacion',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DulceColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: DulceColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onWake,
            icon: Icon(Icons.play_arrow_rounded, size: 18),
            label: Text('Reactivar'),
          ),
        ],
      ),
    );
  }
}

// ==============================================================
// Bottom sheet de pestanas
// ==============================================================
class _TabsBottomSheet extends StatelessWidget {
  final TabManager tabManager;
  final Function(int) onTabSelected;
  final Function(int) onTabClosed;
  final VoidCallback onNewTab;

  const _TabsBottomSheet({
    required this.tabManager,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onNewTab,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: DulceColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tabManager.tabCount,
            itemBuilder: (BuildContext ctx, int index) {
              final DulceTab tab = tabManager.tabs[index];
              final bool isActive = index == tabManager.activeIndex;
              return ListTile(
                leading: Icon(
                  tab.isHibernated
                      ? Icons.bedtime_rounded
                      : Icons.tab_rounded,
                  color: isActive
                      ? DulceColors.primary
                      : DulceColors.textSecondary,
                  size: 18,
                ),
                title: Text(
                  tab.title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? DulceColors.primary
                        : DulceColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  UrlUtils.displayUrl(tab.url),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: DulceColors.textDisabled,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: tabManager.tabCount > 1
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 16, color: DulceColors.textDisabled),
                        onPressed: () => onTabClosed(index),
                      )
                    : null,
                selected: isActive,
                selectedTileColor: DulceColors.primaryAlpha,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () => onTabSelected(index),
              );
            },
          ),
        ),
        if (tabManager.canAddTab)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNewTab,
                icon: Icon(Icons.add_rounded, size: 18),
                label: Text('Nueva pestana'),
              ),
            ),
          ),
      ],
    );
  }
}

// ==============================================================
// Menu principal (bottom sheet)
// ==============================================================
class _MainMenu extends StatelessWidget {
  final String currentUrl;
  final bool isIncognito;
  final VoidCallback onAddBookmark;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onSecurityInfo;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenSettings;
  final VoidCallback onAbout;
  final VoidCallback onOpenIncognito;

  const _MainMenu({
    required this.currentUrl,
    required this.isIncognito,
    required this.onAddBookmark,
    required this.onShare,
    required this.onDownload,
    required this.onSecurityInfo,
    required this.onOpenHistory,
    required this.onOpenDownloads,
    required this.onOpenSettings,
    required this.onAbout,
    required this.onOpenIncognito,
  });

  @override
  Widget build(BuildContext context) {
    final List<_MenuEntry> entries = <_MenuEntry>[
      _MenuEntry(Icon(Icons.bookmark_outline_rounded), 'Agregar a favoritos', onAddBookmark, isDisabled: isIncognito),
      _MenuEntry(Icon(Icons.visibility_off_rounded), 'Nueva pestana de incognito', onOpenIncognito),
      _MenuEntry(Icon(Icons.share_rounded), 'Compartir pagina', onShare),
      _MenuEntry(Icon(Icons.download_rounded), 'Descargar pagina', onDownload),
      _MenuEntry(Icon(Icons.download_for_offline_rounded), 'Descargas', onOpenDownloads),
      _MenuEntry(Icon(Icons.security_rounded), 'Info de seguridad', onSecurityInfo),
      _MenuEntry(Icon(Icons.history_rounded), 'Historial de navegacion', onOpenHistory, isDisabled: isIncognito),
      _MenuEntry(Icon(Icons.settings_rounded), 'Ajustes', onOpenSettings),
      _MenuEntry(Icon(Icons.info_outline_rounded), 'Acerca de DulceNav', onAbout),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: DulceColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        ...entries.map((_MenuEntry e) => ListTile(
              leading: IconTheme(
                data: IconThemeData(
                  size: 20,
                  color: e.isDisabled
                      ? DulceColors.textDisabled
                      : DulceColors.textSecondary,
                ),
                child: e.icon,
              ),
              title: Text(
                e.label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  color: e.isDisabled
                      ? DulceColors.textDisabled
                      : DulceColors.textPrimary,
                  decoration: e.isDisabled ? TextDecoration.lineThrough : null,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                e.onTap();
              },
              dense: true,
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MenuEntry {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool isDisabled;
  const _MenuEntry(this.icon, this.label, this.onTap, {this.isDisabled = false});
}

class _DulceMindDrawer extends StatefulWidget {
  final String activeUrl;
  final String activeTitle;
  final Future<String> Function() getPageText;

  const _DulceMindDrawer({
    required this.activeUrl,
    required this.activeTitle,
    required this.getPageText,
  });

  @override
  State<_DulceMindDrawer> createState() => _DulceMindDrawerState();
}

class _DulceMindDrawerState extends State<_DulceMindDrawer> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSummarizing = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runSummarizeCustom(DulceMindService ai, String length) async {
    setState(() => _isSummarizing = true);
    ai.addMessage(ChatMessage(
      sender: 'user',
      text: 'Resumir esta página (${length == 'short' ? 'Corto' : length == 'key_points' ? 'Puntos clave' : 'Detallado'})',
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();
    try {
      final String text = await widget.getPageText();
      final String summary = await ai.getSummary(widget.activeTitle, text, length: length);
      ai.addMessage(ChatMessage(
        sender: 'dulcemind',
        text: summary,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
    } catch (e) {
      debugPrint('[DulceMind] Error al resumir: $e');
    } finally {
      setState(() => _isSummarizing = false);
    }
  }

  Future<void> _runExplainText(DulceMindService ai, String mode) async {
    setState(() => _isSummarizing = true);
    ai.addMessage(ChatMessage(
      sender: 'user',
      text: 'Explicar contenido de la página (${mode == 'simple' ? 'Sencillo' : 'Técnico'})',
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();
    try {
      final String text = await widget.getPageText();
      final String result = await ai.explainText(text, mode: mode);
      ai.addMessage(ChatMessage(
        sender: 'dulcemind',
        text: result,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
    } catch (e) {
      debugPrint('[DulceMind] Error al explicar: $e');
    } finally {
      setState(() => _isSummarizing = false);
    }
  }

  Future<void> _runTranslateText(DulceMindService ai, String lang) async {
    setState(() => _isSummarizing = true);
    ai.addMessage(ChatMessage(
      sender: 'user',
      text: 'Traducir página al $lang',
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();
    try {
      final String text = await widget.getPageText();
      final String result = await ai.translateText(text, lang);
      ai.addMessage(ChatMessage(
        sender: 'dulcemind',
        text: result,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
    } catch (e) {
      debugPrint('[DulceMind] Error al traducir: $e');
    } finally {
      setState(() => _isSummarizing = false);
    }
  }

  Future<void> _runExtractData(DulceMindService ai, String type) async {
    setState(() => _isSummarizing = true);
    final typeLabel = type == 'dates' ? 'Fechas' : type == 'data' ? 'Datos clave' : 'Pasos/Instrucciones';
    ai.addMessage(ChatMessage(
      sender: 'user',
      text: 'Extraer $typeLabel de la página',
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();
    try {
      final String text = await widget.getPageText();
      final String result = await ai.extractData(text, type);
      ai.addMessage(ChatMessage(
        sender: 'dulcemind',
        text: result,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
    } catch (e) {
      debugPrint('[DulceMind] Error al extraer: $e');
    } finally {
      setState(() => _isSummarizing = false);
    }
  }

  void _showSummarizeOptions(DulceMindService ai) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Opciones de Resumen',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.align_horizontal_left_rounded, color: Colors.white70),
            title: const Text('Resumen Corto', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            subtitle: const Text('Resumen en un máximo de 3 oraciones rápidas.', style: TextStyle(fontFamily: 'Outfit', color: Colors.white30, fontSize: 11)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runSummarizeCustom(ai, 'short');
            },
          ),
          ListTile(
            leading: const Icon(Icons.article_rounded, color: Colors.white70),
            title: const Text('Resumen Detallado', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            subtitle: const Text('Análisis en profundidad de todo el contenido.', style: TextStyle(fontFamily: 'Outfit', color: Colors.white30, fontSize: 11)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runSummarizeCustom(ai, 'detailed');
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_list_bulleted_rounded, color: Colors.white70),
            title: const Text('Puntos Clave', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            subtitle: const Text('Extrae los conceptos clave en una lista numerada.', style: TextStyle(fontFamily: 'Outfit', color: Colors.white30, fontSize: 11)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runSummarizeCustom(ai, 'key_points');
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showExplainOptions(DulceMindService ai) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Opciones de Explicación',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.child_care_rounded, color: Colors.amberAccent),
            title: const Text('Explicación Sencilla', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            subtitle: const Text('Explicar en un lenguaje fácil, cotidiano y accesible.', style: TextStyle(fontFamily: 'Outfit', color: Colors.white30, fontSize: 11)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runExplainText(ai, 'simple');
            },
          ),
          ListTile(
            leading: const Icon(Icons.engineering_rounded, color: Colors.amberAccent),
            title: const Text('Explicación Técnica', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            subtitle: const Text('Análisis técnico riguroso de conceptos.', style: TextStyle(fontFamily: 'Outfit', color: Colors.white30, fontSize: 11)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runExplainText(ai, 'technical');
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showTranslateOptions(DulceMindService ai) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Seleccionar Idioma de Destino',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          ListTile(
            leading: const Text('🇺🇸', style: TextStyle(fontSize: 20)),
            title: const Text('Inglés', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runTranslateText(ai, 'Inglés');
            },
          ),
          ListTile(
            leading: const Text('🇧🇷', style: TextStyle(fontSize: 20)),
            title: const Text('Portugués', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runTranslateText(ai, 'Portugués');
            },
          ),
          ListTile(
            leading: const Text('🇫🇷', style: TextStyle(fontSize: 20)),
            title: const Text('Francés', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runTranslateText(ai, 'Francés');
            },
          ),
          ListTile(
            leading: const Text('🇩🇪', style: TextStyle(fontSize: 20)),
            title: const Text('Alemán', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runTranslateText(ai, 'Alemán');
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showExtractOptions(DulceMindService ai) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Seleccionar Tipo de Extracción',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.date_range_rounded, color: Colors.greenAccent),
            title: const Text('Fechas y Eventos', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runExtractData(ai, 'dates');
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics_rounded, color: Colors.greenAccent),
            title: const Text('Datos y Cifras clave', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runExtractData(ai, 'data');
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_list_numbered_rounded, color: Colors.greenAccent),
            title: const Text('Pasos o Instrucciones', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.of(ctx).pop();
              _runExtractData(ai, 'steps');
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildActionChips(DulceMindService ai, ThemeService theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildQuickChip(
            icon: Icons.summarize_rounded,
            label: 'Resumir',
            onTap: () => _showSummarizeOptions(ai),
            color: theme.activePrimaryColor,
          ),
          const SizedBox(width: 8),
          _buildQuickChip(
            icon: Icons.psychology_alt_rounded,
            label: 'Explicar',
            onTap: () => _showExplainOptions(ai),
            color: Colors.amberAccent,
          ),
          const SizedBox(width: 8),
          _buildQuickChip(
            icon: Icons.g_translate_rounded,
            label: 'Traducir',
            onTap: () => _showTranslateOptions(ai),
            color: Colors.lightBlueAccent,
          ),
          const SizedBox(width: 8),
          _buildQuickChip(
            icon: Icons.fact_check_rounded,
            label: 'Extraer',
            onTap: () => _showExtractOptions(ai),
            color: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({required IconData icon, required String label, required VoidCallback onTap, required Color color}) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: Colors.white.withOpacity(0.04),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: onTap,
    );
  }

  Widget _buildModelNotDownloadedCard(DulceMindService ai, ThemeService theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.activePrimaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.activePrimaryColor.withOpacity(0.3),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_for_offline_rounded, color: theme.activePrimaryColor, size: 40),
              const SizedBox(height: 12),
              const Text(
                '🤖 Función de IA Opcional',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Para usar resúmenes, explicaciones y chat necesitas descargar ~1.2 GB una sola vez.\n\n'
                '• Nada se envía a internet: todo funciona dentro de tu dispositivo.\n'
                '• Si no la usas: el resto del navegador sigue funcionando igual.',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (ai.isDownloading) ...[
                LinearProgressIndicator(
                  value: ai.downloadProgress > 0 ? ai.downloadProgress : null,
                  backgroundColor: Colors.white12,
                  color: theme.activePrimaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(ai.downloadProgress * 100).toStringAsFixed(1)}% | ${ai.downloadSpeed}',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.white70),
                ),
              ] else ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.activePrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Descargar Llama 3.2 1B (~1.2 GB)', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ai.downloadModel(AppConfig.llama3_2_1b_config);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DulceMindService ai = context.watch<DulceMindService>();
    final double width = MediaQuery.of(context).size.width * 0.40;
    final theme = context.watch<ThemeService>();
    final blurSigma = theme.blurSigma;

    return Drawer(
      width: width > 350 ? width : 350,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181828).withOpacity(theme.highContrast ? 1.0 : 0.82),
              border: Border(
                left: BorderSide(
                  color: theme.activeBorderColor,
                  width: 1.2,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  // Cabecera del panel
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.psychology_rounded, color: DulceColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'DulceMind IA Local',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: DulceColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: ai.isModelDownloaded ? DulceColors.safeGreen : DulceColors.warningYellow,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ai.statusMessage,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10.5,
                                    color: DulceColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: DulceColors.textSecondary, size: 18),
                          onPressed: () {
                            Navigator.of(context).pop();
                            ai.resetInactivityTimer();
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: DulceColors.border),

                  // Chips rápidos si está el modelo listo
                  if (ai.isModelDownloaded)
                    _buildActionChips(ai, theme),

                  if (ai.isModelDownloaded && _isSummarizing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Procesando en el dispositivo...',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                  // Historial de chat o tarjeta de descarga
                  Expanded(
                    child: !ai.isModelDownloaded
                        ? _buildModelNotDownloadedCard(ai, theme)
                        : ai.chatHistory.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(Icons.chat_bubble_outline_rounded, size: 36, color: DulceColors.textDisabled),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Pregúntame algo sobre esta página...',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 14,
                                          color: DulceColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                itemCount: ai.chatHistory.length,
                                itemBuilder: (BuildContext ctx, int idx) {
                                  final ChatMessage msg = ai.chatHistory[idx];
                                  final bool isUser = msg.sender == 'user';
                                  return Align(
                                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      padding: const EdgeInsets.all(12),
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.32),
                                      decoration: BoxDecoration(
                                        color: isUser ? DulceColors.primaryAlpha : DulceColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(10).copyWith(
                                          topRight: isUser ? Radius.zero : const Radius.circular(10),
                                          topLeft: isUser ? const Radius.circular(10) : Radius.zero,
                                        ),
                                        border: Border.all(
                                          color: isUser ? DulceColors.primary.withOpacity(0.3) : DulceColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        msg.text,
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 14,
                                          color: DulceColors.textPrimary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),

                  // Entrada de texto inferior
                  if (ai.isModelDownloaded) ...[
                    Container(height: 1, color: DulceColors.border),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: DulceColors.surface,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _questionController,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Hacer una pregunta...',
                                hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: DulceColors.textDisabled),
                                isDense: true,
                              ),
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: DulceColors.textPrimary),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (String val) => _sendQuestion(ai, val),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.send_rounded, color: DulceColors.primary, size: 20),
                            onPressed: () => _sendQuestion(ai, _questionController.text),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sendQuestion(DulceMindService ai, String val) {
    if (val.trim().isEmpty) return;
    final String cleanVal = val.trim();
    _questionController.clear();
    widget.getPageText().then((String text) {
      ai.askQuestion(cleanVal, widget.activeTitle, text).then((_) {
        _scrollToBottom();
      });
    });
  }
}

// ==============================================================
// Drawer de Historial de Navegacion (Lateral izquierdo)
// ==============================================================
class _HistoryDrawer extends StatefulWidget {
  final Function(String) onNavigate;
  final VoidCallback onClose;

  const _HistoryDrawer({
    required this.onNavigate,
    required this.onClose,
  });

  @override
  State<_HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<_HistoryDrawer> {
  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${pad(dt.hour)}:${pad(dt.minute)} - ${pad(dt.day)}/${pad(dt.month)}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width * 0.40; // 40% del ancho en escritorio
    final historyList = StorageService.instance.history;

    return Drawer(
      width: width > 350 ? width : 350, // minimo 350px
      backgroundColor: DulceColors.surface,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // Cabecera del panel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Icon(Icons.history_rounded, color: DulceColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Historial de navegacion',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DulceColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: DulceColors.textSecondary, size: 20),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(color: DulceColors.border, height: 1),

            // Lista de URLs visitadas
            Expanded(
              child: historyList.isEmpty
                  ? Center(
                      child: Text(
                        'No hay paginas en el historial',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: historyList.length,
                      itemBuilder: (context, index) {
                        final item = historyList[index];
                        String title = '';
                        String url = '';
                        int timestamp = 0;

                        try {
                          final decoded = jsonDecode(item);
                          if (decoded is Map) {
                            url = decoded['url']?.toString() ?? item;
                            title = decoded['title']?.toString() ?? '';
                            timestamp = decoded['timestamp'] as int? ?? 0;
                          } else {
                            url = item;
                            title = UrlUtils.getDomain(item);
                          }
                        } catch (_) {
                          url = item;
                          title = UrlUtils.getDomain(item);
                        }

                        if (title.isEmpty) {
                          title = UrlUtils.getDomain(url);
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: DulceColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                url,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  color: DulceColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (timestamp > 0)
                                Text(
                                  _formatTimestamp(timestamp),
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    color: DulceColors.textDisabled,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            widget.onClose();
                            widget.onNavigate(url);
                          },
                        );
                      },
                    ),
            ),
            Divider(color: DulceColors.border, height: 1),

            // Boton de borrar historial
            if (historyList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DulceColors.dangerRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await StorageService.instance.clearHistory();
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    icon: Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Borrar historial',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Pantalla de Carga Suave del WebView ───────────────────────
class _LoadingOverlay extends StatelessWidget {
  final bool isLoading;

  const _LoadingOverlay({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isLoading,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isLoading ? 1.0 : 0.0,
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            gradient: DulceColors.backgroundGradient, // NO fondo negro puro
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: DulceColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: DulceColors.primary.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.travel_explore_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(DulceColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cargando...',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: DulceColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pantalla de Error Amigable del WebView ────────────────────
class _ErrorOverlay extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onGoHome;

  const _ErrorOverlay({
    required this.errorMessage,
    required this.onRetry,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: DulceColors.backgroundGradient,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: DulceColors.dangerRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DulceColors.dangerRed.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: DulceColors.dangerRed.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: DulceColors.dangerRed,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No se pudo cargar la pagina',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Verifica tu conexion a internet o la direccion escrita.\nDetalle: $errorMessage',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: DulceColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DulceColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Reintentar', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    onPressed: onRetry,
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.home_rounded, size: 18),
                    label: const Text('Inicio', style: TextStyle(fontFamily: 'Outfit')),
                    onPressed: onGoHome,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Barra de Progreso con Destello de Luz (Shimmer Glint) ───────
class DulceProgressBar extends StatefulWidget {
  final double? value;
  const DulceProgressBar({super.key, this.value});

  @override
  State<DulceProgressBar> createState() => _DulceProgressBarState();
}

class _DulceProgressBarState extends State<DulceProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _glintController;

  @override
  void initState() {
    super.initState();
    _glintController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _glintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.value ?? 0.0;
    return Container(
      height: 3, // slightly thicker but still thin
      width: double.infinity,
      color: DulceColors.border,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * progress;
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: _glintController,
              builder: (context, child) {
                return Container(
                  width: width,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        DulceColors.primary,
                        Color(0xFF8C85FF),
                        Colors.white, // white glint
                        Color(0xFF8C85FF),
                        DulceColors.primary,
                      ],
                      stops: [
                        0.0,
                        (_glintController.value - 0.15).clamp(0.0, 1.0),
                        _glintController.value,
                        (_glintController.value + 0.15).clamp(0.0, 1.0),
                        1.0,
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ActiveWebViewKey {
  final _BrowserScreenState state;
  _ActiveWebViewKey(this.state);
  DulceWebViewState? get currentState => state._activeWebViewState;

  BuildContext? get currentContext {
    try {
      final tabManager = state.context.read<TabManager>();
      final activeTabId = tabManager.activeTab.id;
      return state._webViewKeys[activeTabId]?.currentContext;
    } catch (_) {
      return null;
    }
  }
}
