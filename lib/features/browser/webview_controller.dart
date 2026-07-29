// ==============================================================
// DulceNav - webview_controller.dart
// Controlador abstracto multiplataforma del WebView.
// Desacopla la logica de navegacion del widget de UI.
// Permite cambiar el motor de renderizado sin tocar la UI.
// ==============================================================

import 'package:flutter/foundation.dart';
import '../../core/constants/app_config.dart';

// --------------------------------------------------------------
// Enum de estado de carga
// --------------------------------------------------------------
enum WebViewLoadState { idle, loading, finished, error }

// --------------------------------------------------------------
// Modelo de informacion de pagina cargada
// --------------------------------------------------------------
class PageInfo {
  final String url;
  final String title;
  final bool canGoBack;
  final bool canGoForward;

  const PageInfo({
    required this.url,
    required this.title,
    required this.canGoBack,
    required this.canGoForward,
  });

  PageInfo copyWith({
    String? url,
    String? title,
    bool? canGoBack,
    bool? canGoForward,
  }) {
    return PageInfo(
      url: url ?? this.url,
      title: title ?? this.title,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
    );
  }
}

// --------------------------------------------------------------
// Controlador de WebView observable
// Notifica a la UI sobre cambios de estado de navegacion.
// --------------------------------------------------------------
class WebViewController extends ChangeNotifier {
  // Estado de carga
  WebViewLoadState _loadState = WebViewLoadState.idle;
  WebViewLoadState get loadState => _loadState;
  bool get isLoading => _loadState == WebViewLoadState.loading;

  // Informacion de la pagina actual
  PageInfo _pageInfo = const PageInfo(
    url: AppConfig.homeUrl,
    title: 'Nueva pestana',
    canGoBack: false,
    canGoForward: false,
  );
  PageInfo get pageInfo => _pageInfo;

  // Progreso de carga (0.0 a 1.0)
  double _loadProgress = 0.0;
  double get loadProgress => _loadProgress;

  // Contador de elementos bloqueados (Fase 2 actualiza esto)
  int _blockedCount = 0;
  int get blockedCount => _blockedCount;

  // Error de carga (null si no hay error)
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // --------------------------------------------------------------
  // Metodos para actualizar estado (llamados desde el WebView widget)
  // --------------------------------------------------------------

  void onPageStarted(String url) {
    _loadState = WebViewLoadState.loading;
    _loadProgress = 0.1;
    _errorMessage = null;
    _pageInfo = _pageInfo.copyWith(url: url);
    notifyListeners();
  }

  void onPageProgress(int progress) {
    _loadProgress = progress / 100.0;
    notifyListeners();
  }

  void onPageFinished(String url, {String? title}) {
    _loadState = WebViewLoadState.finished;
    _loadProgress = 1.0;
    _pageInfo = _pageInfo.copyWith(
      url: url,
      title: title ?? _pageInfo.title,
    );
    notifyListeners();
  }

  void onPageError(String description) {
    _loadState = WebViewLoadState.error;
    _errorMessage = description;
    notifyListeners();
  }

  void onUrlChanged(String url) {
    _pageInfo = _pageInfo.copyWith(url: url);
    notifyListeners();
  }

  void onTitleChanged(String title) {
    _pageInfo = _pageInfo.copyWith(title: title);
    notifyListeners();
  }

  void onNavigationStateChanged({required bool canGoBack, required bool canGoForward}) {
    _pageInfo = _pageInfo.copyWith(
      canGoBack: canGoBack,
      canGoForward: canGoForward,
    );
    notifyListeners();
  }

  void onRequestBlocked() {
    _blockedCount++;
    notifyListeners();
  }

  void resetBlockedCount() {
    _blockedCount = 0;
    notifyListeners();
  }

  // --------------------------------------------------------------
  // Reset al cambiar de pestana
  // --------------------------------------------------------------
  void resetForNewTab(String url) {
    _loadState = WebViewLoadState.idle;
    _loadProgress = 0.0;
    _errorMessage = null;
    _blockedCount = 0;
    _pageInfo = PageInfo(
      url: url,
      title: url == AppConfig.homeUrl ? 'Nueva pestana' : url,
      canGoBack: false,
      canGoForward: false,
    );
    notifyListeners();
  }
}
