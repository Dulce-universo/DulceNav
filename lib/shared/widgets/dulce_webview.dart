// ==============================================================
// DulceNav - dulce_webview.dart
// Fachada común multiplataforma para el motor del navegador.
// Delegación a WebView2 en Windows y InAppWebView en Android.
// ==============================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../platform/windows/windows_webview.dart';
import '../../platform/android/android_webview.dart';

class DulceWebView extends StatefulWidget {
  final String initialUrl;
  final String tabId;
  final bool isIncognito;
  final Function(String url)? onUrlChanged;
  final Function(String title)? onTitleChanged;
  final Function(bool loading)? onLoadingChanged;
  final Function(int count)? onRequestBlocked;
  final Function(dynamic message)? onWebMessageReceived;
  final Function(String error)? onReceivedError;

  const DulceWebView({
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
  State<DulceWebView> createState() => DulceWebViewState();
}

class DulceWebViewState extends State<DulceWebView> with AutomaticKeepAliveClientMixin<DulceWebView> {
  // Claves de plataforma internas
  final _windowsKey = GlobalKey<WindowsWebViewState>();
  final _androidKey = GlobalKey<AndroidWebViewState>();

  @override
  bool get wantKeepAlive => true;

  // ── API unificada pública ───────────────────────────────────

  Future<void> loadUrl(String url) async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.loadUrl(url);
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.loadUrl(url);
    }
  }

  Future<void> goBack() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.goBack();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.goBack();
    }
  }

  Future<void> goForward() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.goForward();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.goForward();
    }
  }

  Future<void> reload() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.reload();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.reload();
    }
  }

  Future<void> stopLoading() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.stopLoading();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.stopLoading();
    }
  }

  Future<void> setZoomFactor(double zoomFactor) async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.setZoomFactor(zoomFactor);
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.setZoomFactor(zoomFactor);
    }
  }

  Future<void> reloadBypassingCache() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.reloadBypassingCache();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.reloadBypassingCache();
    }
  }

  Future<String> getPageText() async {
    if (kIsWeb) return '';
    if (Platform.isWindows) {
      return await _windowsKey.currentState?.getPageText() ?? '';
    } else if (Platform.isAndroid) {
      return await _androidKey.currentState?.getPageText() ?? '';
    }
    return '';
  }

  Future<String> getPageHtml() async {
    if (kIsWeb) return '';
    if (Platform.isWindows) {
      return await _windowsKey.currentState?.getPageHtml() ?? '';
    } else if (Platform.isAndroid) {
      return await _androidKey.currentState?.getPageHtml() ?? '';
    }
    return '';
  }

  Future<void> autofillCredentials(String username, String password) async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.autofillCredentials(username, password);
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.autofillCredentials(username, password);
    }
  }

  Future<dynamic> executeScript(String code) async {
    if (kIsWeb) return null;
    if (Platform.isWindows) {
      return await _windowsKey.currentState?.executeScript(code);
    } else if (Platform.isAndroid) {
      return await _androidKey.currentState?.executeScript(code);
    }
    return null;
  }

  Future<void> suspendRenderer() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.suspendRenderer();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.suspendRenderer();
    }
  }

  Future<void> resumeRenderer() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.resumeRenderer();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.resumeRenderer();
    }
  }

  Future<void> pause() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.pause();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.pause();
    }
  }

  Future<void> resume() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.resume();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.resume();
    }
  }

  Future<void> setFpsLimit(int fps) async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.setFpsLimit(fps);
    } // Android no requiere throttling de FPS por ciclo de pintado nativo
  }

  Future<void> openDevTools() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.openDevTools();
    } // Android no abre DevTools de forma local sino via debugger USB remoto
  }

  Future<void> updateContextMenuSetting(bool enabled) async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.updateContextMenuSetting(enabled);
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.updateContextMenuSetting(enabled);
    }
  }

  Future<String> getCookiesForDomain(String domain) async {
    if (kIsWeb) return '[]';
    if (Platform.isWindows) {
      return await _windowsKey.currentState?.getCookiesForDomain(domain) ?? '[]';
    } else if (Platform.isAndroid) {
      return await _androidKey.currentState?.getCookiesForDomain(domain) ?? '[]';
    }
    return '[]';
  }

  Future<void> clearCookiesForDomain(String domain) async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.clearCookiesForDomain(domain);
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.clearCookiesForDomain(domain);
    }
  }

  Future<void> setLowMemoryMode() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.setLowMemoryMode();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.setLowMemoryMode();
    }
  }

  Future<void> setNormalMemoryMode() async {
    if (kIsWeb) return;
    if (Platform.isWindows) {
      await _windowsKey.currentState?.setNormalMemoryMode();
    } else if (Platform.isAndroid) {
      await _androidKey.currentState?.setNormalMemoryMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (kIsWeb) {
      return const Center(child: Text('Web no soportado en esta fase.'));
    }

    if (Platform.isWindows) {
      return WindowsWebView(
        key: _windowsKey,
        initialUrl: widget.initialUrl,
        tabId: widget.tabId,
        isIncognito: widget.isIncognito,
        onUrlChanged: widget.onUrlChanged,
        onTitleChanged: widget.onTitleChanged,
        onLoadingChanged: widget.onLoadingChanged,
        onRequestBlocked: widget.onRequestBlocked,
        onWebMessageReceived: widget.onWebMessageReceived,
        onReceivedError: widget.onReceivedError,
      );
    } else if (Platform.isAndroid) {
      return AndroidWebView(
        key: _androidKey,
        initialUrl: widget.initialUrl,
        tabId: widget.tabId,
        isIncognito: widget.isIncognito,
        onUrlChanged: widget.onUrlChanged,
        onTitleChanged: widget.onTitleChanged,
        onLoadingChanged: widget.onLoadingChanged,
        onRequestBlocked: widget.onRequestBlocked,
        onWebMessageReceived: widget.onWebMessageReceived,
        onReceivedError: widget.onReceivedError,
      );
    } else {
      return const Center(child: Text('Plataforma no soportada.'));
    }
  }
}
