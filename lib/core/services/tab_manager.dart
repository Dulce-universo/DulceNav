// ============================================================
// DulceNav — tab_manager.dart
// Sistema de gestión de pestañas con hibernación automática.
// Libera WebView y recursos de pestañas inactivas.
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/app_config.dart';
import 'storage_service.dart';

// --- Modelo de una pestana ----------------------------------
class DulceTab {
  final String id;
  String url;
  String title;
  String? favicon;
  bool isHibernated;
  bool isLoading;
  bool hasActiveMedia; // Audio/video activo en segundo plano
  DateTime lastActiveAt;
  final bool isIncognito;
  dynamic controller; // Instancia de controlador de la plataforma
  dynamic keepAliveToken; // Token para mantener el motor activo

  DulceTab({
    required this.id,
    required this.url,
    this.title = 'Nueva pestana',
    this.favicon,
    this.isHibernated = false,
    this.isLoading = false,
    this.hasActiveMedia = false,
    this.isIncognito = false,
  }) : lastActiveAt = DateTime.now();

  // Tiempo de inactividad en minutos
  int get inactiveMinutes =>
      DateTime.now().difference(lastActiveAt).inMinutes;

  // ¿Debe hibernarse?
  bool get shouldHibernate {
    if (!StorageService.instance.tabHibernateEnabled) return false;
    if (isHibernated) return false;
    if (hasActiveMedia) return false; // NUNCA hibernar si tiene audio/video activo
    final isGameMode = StorageService.instance.gameModeEnabled;
    final limitMinutes = isGameMode ? 1 : StorageService.instance.tabHibernateMinutes;
    return inactiveMinutes >= limitMinutes;
  }

  // ¿Debe descargarse completamente?
  bool get shouldUnload =>
      inactiveMinutes >= AppConfig.tabUnloadMinutes;

  @override
  String toString() => 'DulceTab($id: $title)';
}

// --- Manager ─────────────────────────────────────────────────
class TabManager extends ChangeNotifier {
  final List<DulceTab> _tabs = [];
  int _activeIndex = 0;
  Timer? _hibernationTimer;

  // Callbacks opcionales: BrowserScreen los registra para
  // reaccionar a cambios de hibernacion sin polling.
  Function(String tabId)? onTabHibernated;
  Function(String tabId)? onTabWoken;

  TabManager() {
    // Pestaña inicial
    _tabs.add(DulceTab(
      id: _generateId(),
      url: 'https://www.google.com',
      title: 'Google',
    ));
    _startHibernationTimer();
  }

  // ── Getters ────────────────────────────────────────────
  List<DulceTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  DulceTab get activeTab => _tabs[_activeIndex];
  int get tabCount => _tabs.length;
  bool get canAddTab => tabCount < AppConfig.maxTabs;

  bool isActiveTab(String tabId) =>
      _tabs.isNotEmpty && _tabs[_activeIndex].id == tabId;

  // --- Anadir pestana ------------------------------------
  void addTab({String url = 'https://www.google.com', bool isIncognito = false}) {
    if (!canAddTab) return;

    final newTab = DulceTab(
      id: _generateId(),
      url: url,
      title: (url == 'about:dulcenav' || url == 'https://www.google.com') ? 'Google' : url,
      isIncognito: isIncognito,
    );
    _tabs.add(newTab);
    _activeIndex = _tabs.length - 1;
    notifyListeners();
  }

  // ── Cerrar pestaña ─────────────────────────────────────
  void closeTab(int index) {
    if (_tabs.length <= 1) return; // Siempre debe haber al menos 1

    _tabs.removeAt(index);

    // Ajustar índice activo
    if (_activeIndex >= _tabs.length) {
      _activeIndex = _tabs.length - 1;
    } else if (_activeIndex > index) {
      _activeIndex--;
    }
    notifyListeners();
  }

  // ── Hibernar una pestana bajo demanda ──────────────────
  void forceHibernate(String tabId) {
    final tab = _findById(tabId);
    if (tab == null) return;
    final idx = _tabs.indexOf(tab);
    if (idx == _activeIndex) return; // No hibernar la activa
    if (!tab.isHibernated) {
      _hibernateTab(tab);
      notifyListeners();
    }
  }

  // ── Cambiar a pestaña ───────────────────────────────────
  void switchTo(int index) {
    if (index < 0 || index >= _tabs.length) return;

    // Marcar la pestaña anterior como "no activa"
    // (el timer de hibernación la procesará si está inactiva)
    _activeIndex = index;

    // Reactivar pestaña si estaba hibernada
    final tab = _tabs[index];
    if (tab.isHibernated) {
      _wakeTab(tab);
    }

    tab.lastActiveAt = DateTime.now();
    notifyListeners();
  }

  // ── Actualizar info de pestaña ──────────────────────────
  void updateTab({
    required String tabId,
    String? url,
    String? title,
    String? favicon,
    bool? isLoading,
  }) {
    final tab = _findById(tabId);
    if (tab == null) return;

    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (favicon != null) tab.favicon = favicon;
    if (isLoading != null) tab.isLoading = isLoading;
    tab.lastActiveAt = DateTime.now();
    notifyListeners();
  }

  // ── Establecer estado multimedia activo ──────────────────
  void setMediaActive(String tabId, bool active) {
    final tab = _findById(tabId);
    if (tab == null) return;
    if (tab.hasActiveMedia != active) {
      tab.hasActiveMedia = active;
      debugPrint('[TabManager] Estado de media para ${tab.title} cambiado a: $active');
      notifyListeners();
    }
  }

  void _startHibernationTimer() {
    _hibernationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _processHibernation();
    });
  }

  void _processHibernation() {
    bool changed = false;
    for (int i = 0; i < _tabs.length; i++) {
      if (i == _activeIndex) continue; // Nunca hibernar la pestaña activa

      final tab = _tabs[i];
      if (tab.shouldHibernate) {
        _hibernateTab(tab);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void _hibernateTab(DulceTab tab) {
    tab.isHibernated = true;
    debugPrint('[TabManager] Pestana hibernada: ${tab.title}');
    // Notificar a BrowserScreen para que suspenda el renderer
    onTabHibernated?.call(tab.id);
  }

  void _wakeTab(DulceTab tab) {
    tab.isHibernated = false;
    debugPrint('[TabManager] Pestana reactivada: ${tab.title}');
    
    // Regla de restauracion inteligente
    if (!tab.hasActiveMedia) {
      // Comportamiento actual: recargar desde URL
      tab.controller?.loadUrl(tab.url);
    } else {
      // Si tiene media activo: solo reanudar el renderizado, SIN recargar
      tab.controller?.resume();
    }
    
    // Notificar a BrowserScreen para que reanude el renderer
    onTabWoken?.call(tab.id);
  }

  // ── Utilidades ──────────────────────────────────────────
  DulceTab? _findById(String id) {
    try {
      return _tabs.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  int _idCounter = 0;
  String _generateId() => 'tab_${++_idCounter}_${DateTime.now().millisecondsSinceEpoch}';

  // ── Dispose ─────────────────────────────────────────────
  @override
  void dispose() {
    _hibernationTimer?.cancel();
    super.dispose();
  }
}
