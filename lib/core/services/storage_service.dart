// ============================================================
// DulceNav — storage_service.dart
// Almacenamiento local de preferencias del usuario.
// Singleton con inicialización lazy.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'password_service.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;

  // ── Inicialización ─────────────────────────────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await migrateCookiesToEncrypted();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'StorageService.init() must be called first');
    return _prefs!;
  }

  // ── Claves ─────────────────────────────────────────────
  static const String _keyAdBlockEnabled = 'ad_block_enabled';
  static const String _keyTrackingProtection = 'tracking_protection';
  static const String _keyAntiPhishing = 'anti_phishing';
  static const String _keyAiEnabled = 'ai_enabled';
  static const String _keySearchEngine = 'search_engine';
  static const String _keyTabHibernateMinutes = 'tab_hibernate_minutes';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyAcceptedLegal = 'accepted_legal';
  static const String _keyDownloadPath = 'download_path';
  static const String _keyAskDownloadLocation = 'ask_download_location';
  static const String _keyPrimaryColorName = 'primary_color_name';
  static const String _keyUiScale = 'ui_scale';
  static const String _keyThemePreset = 'theme_preset_new';
  static const String _keyHighContrast = 'high_contrast';
  static const String _keyBlurIntensity = 'blur_intensity';
  static const String _keyClearOnClose = 'clear_on_close';
  static const String _keyCookieWhitelist = 'cookie_whitelist';
  static const String _keySiteIsolation = 'site_isolation';
  static const String _keyContextMenuEnabled = 'context_menu_enabled';
  static const String _keySearchOptimizerEnabled = 'search_optimizer_enabled';
  static const String _keyAiPersistentHistory = 'ai_persistent_history';
  static const String _keyAiModel = 'ai_model';
  static const String _keyAiHideFeature = 'ai_hide_feature';
  static const String _keyAiKeepLoaded = 'ai_keep_loaded';
  static const String _keyAiActiveModelPath = 'ai_active_model_path';
  static const String _keyAiActiveModelId = 'ai_active_model_id';
  static const String _keyMaxCacheSizeMb = 'max_cache_size_mb';
  static const String _keyAutoCleanCache = 'auto_clean_cache';
  static const String _keyGameModeEnabled = 'game_mode_enabled';
  static const String _keySessionDomains = 'session_domains';
  static const String _keyLoginNotifications = 'login_notifications';
  static const String _keyAutoSaveSessions = 'auto_save_sessions';
  static const String _keyShowBookmarksBar = 'show_bookmarks_bar';
  static const String _keyManualLocationEnabled = 'manual_location_enabled';
  static const String _keyManualLocationCity = 'manual_location_city';
  static const String _keyManualLocationLatitude = 'manual_location_latitude';
  static const String _keyManualLocationLongitude = 'manual_location_longitude';

  // ── Getters/Setters: Bloqueo ────────────────────────────
  bool get adBlockEnabled =>
      _p.getBool(_keyAdBlockEnabled) ?? true; // ON por defecto
  Future<void> setAdBlockEnabled(bool v) async {
    await _p.setBool(_keyAdBlockEnabled, v);
    await updateSettingsTimestamp();
  }

  bool get trackingProtectionEnabled =>
      _p.getBool(_keyTrackingProtection) ?? true;
  Future<void> setTrackingProtection(bool v) async {
    await _p.setBool(_keyTrackingProtection, v);
    await updateSettingsTimestamp();
  }

  bool get antiPhishingEnabled =>
      _p.getBool(_keyAntiPhishing) ?? true;
  Future<void> setAntiPhishing(bool v) async {
    await _p.setBool(_keyAntiPhishing, v);
    await updateSettingsTimestamp();
  }

  // ── Getters/Setters: IA ─────────────────────────────────
  bool get aiEnabled =>
      _p.getBool(_keyAiEnabled) ?? false; // OFF por defecto
  Future<void> setAiEnabled(bool v) async {
    await _p.setBool(_keyAiEnabled, v);
    await updateSettingsTimestamp();
  }

  bool get aiPersistentHistory =>
      _p.getBool(_keyAiPersistentHistory) ?? false;
  Future<void> setAiPersistentHistory(bool v) async {
    await _p.setBool(_keyAiPersistentHistory, v);
    await updateSettingsTimestamp();
  }

  String get aiModel => _p.getString(_keyAiModel) ?? 'llama-3.2-1b-instruct';
  Future<void> setAiModel(String v) async {
    await _p.setString(_keyAiModel, v);
    await updateSettingsTimestamp();
  }

  bool get aiHideFeature => _p.getBool(_keyAiHideFeature) ?? false;
  Future<void> setAiHideFeature(bool v) async {
    await _p.setBool(_keyAiHideFeature, v);
    await updateSettingsTimestamp();
  }

  bool get aiKeepLoaded => _p.getBool(_keyAiKeepLoaded) ?? false;
  Future<void> setAiKeepLoaded(bool v) async {
    await _p.setBool(_keyAiKeepLoaded, v);
    await updateSettingsTimestamp();
  }

  String get aiActiveModelPath => _p.getString(_keyAiActiveModelPath) ?? '';
  Future<void> setAiActiveModelPath(String v) async {
    await _p.setString(_keyAiActiveModelPath, v);
    await updateSettingsTimestamp();
  }

  String get aiActiveModelId => _p.getString(_keyAiActiveModelId) ?? '';
  Future<void> setAiActiveModelId(String v) async {
    await _p.setString(_keyAiActiveModelId, v);
    await updateSettingsTimestamp();
  }

  // ── Getters/Setters: Menu Contextual y Buscador ─────────
  bool get contextMenuEnabled =>
      _p.getBool(_keyContextMenuEnabled) ?? true;
  Future<void> setContextMenuEnabled(bool v) =>
      _p.setBool(_keyContextMenuEnabled, v);

  bool get searchOptimizerEnabled =>
      _p.getBool(_keySearchOptimizerEnabled) ?? true;
  Future<void> setSearchOptimizerEnabled(bool v) =>
      _p.setBool(_keySearchOptimizerEnabled, v);

  // ── Getters/Setters: Rendimiento y Cache ──────────────────
  int get maxCacheSizeMb =>
      _p.getInt(_keyMaxCacheSizeMb) ?? 80;
  Future<void> setMaxCacheSizeMb(int v) =>
      _p.setInt(_keyMaxCacheSizeMb, v);

  bool get autoCleanCache =>
      _p.getBool(_keyAutoCleanCache) ?? true;
  Future<void> setAutoCleanCache(bool v) =>
      _p.setBool(_keyAutoCleanCache, v);

  bool get gameModeEnabled =>
      _p.getBool(_keyGameModeEnabled) ?? false;
  Future<void> setGameModeEnabled(bool v) =>
      _p.setBool(_keyGameModeEnabled, v);

  // -- Getters/Setters: Sesiones y Cuentas --------------------------
  List<String> get sessionDomains =>
      _p.getStringList(_keySessionDomains) ?? [];
  Future<void> setSessionDomains(List<String> v) =>
      _p.setStringList(_keySessionDomains, v);

  bool get loginNotifications =>
      _p.getBool(_keyLoginNotifications) ?? true;
  Future<void> setLoginNotifications(bool v) =>
      _p.setBool(_keyLoginNotifications, v);

  bool get autoSaveSessions =>
      _p.getBool(_keyAutoSaveSessions) ?? true;
  Future<void> setAutoSaveSessions(bool v) =>
      _p.setBool(_keyAutoSaveSessions, v);

  // Session data keyed per domain (base64 JSON of cookie metadata)
  Future<String?> getSessionData(String domain) async {
    final encrypted = _p.getString('session_data_$domain');
    if (encrypted == null || encrypted.isEmpty) return null;
    return await PasswordService.instance.decryptText(encrypted);
  }

  Future<void> setSessionData(String domain, String data) async {
    final encrypted = await PasswordService.instance.encryptText(data);
    if (encrypted != null) {
      await _p.setString('session_data_$domain', encrypted);
    }
  }

  bool hasSessionData(String domain) =>
      _p.containsKey('session_data_$domain');

  Future<void> clearSessionData(String domain) =>
      _p.remove('session_data_$domain');

  // ── Getters/Setters: Motor de búsqueda ─────────────────
  String get searchEngine =>
      _p.getString(_keySearchEngine) ??
      'https://duckduckgo.com/?q=';
  Future<void> setSearchEngine(String v) async {
    await _p.setString(_keySearchEngine, v);
    await updateSettingsTimestamp();
  }

  // ── Getters/Setters: Pestañas ───────────────────────────
  int get tabHibernateMinutes =>
      _p.getInt(_keyTabHibernateMinutes) ?? 15;
  Future<void> setTabHibernateMinutes(int v) async {
    await _p.setInt(_keyTabHibernateMinutes, v);
    await updateSettingsTimestamp();
  }

  // ── Getters/Setters: Primera vez ────────────────────────
  bool get isFirstLaunch => _p.getBool(_keyFirstLaunch) ?? true;
  Future<void> markLaunched() => _p.setBool(_keyFirstLaunch, false);

  bool get acceptedLegal => _p.getBool(_keyAcceptedLegal) ?? false;
  Future<void> acceptLegal() => _p.setBool(_keyAcceptedLegal, true);

  // ── Getters/Setters: Descargas ──────────────────────────
  String get downloadPath =>
      _p.getString(_keyDownloadPath) ?? r'D:\Descargas\DulceNav\';
  Future<void> setDownloadPath(String v) =>
      _p.setString(_keyDownloadPath, v);

  bool get askDownloadLocation =>
      _p.getBool(_keyAskDownloadLocation) ?? false;
  Future<void> setAskDownloadLocation(bool v) =>
      _p.setBool(_keyAskDownloadLocation, v);

  // ── Getters/Setters: Personalización ─────────────────────
  String get primaryColorName =>
      _p.getString(_keyPrimaryColorName) ?? 'morado';
  Future<void> setPrimaryColorName(String v) =>
      _p.setString(_keyPrimaryColorName, v);

  double get uiScale =>
      _p.getDouble(_keyUiScale) ?? 1.0;
  Future<void> setUiScale(double v) =>
      _p.setDouble(_keyUiScale, v);

  String get themePreset => _p.getString(_keyThemePreset) ?? 'dulceClassic';
  Future<void> setThemePreset(String v) async {
    await _p.setString(_keyThemePreset, v);
    await updateSettingsTimestamp();
  }

  bool get highContrast => _p.getBool(_keyHighContrast) ?? false;
  Future<void> setHighContrast(bool v) => _p.setBool(_keyHighContrast, v);

  String get blurIntensity => _p.getString(_keyBlurIntensity) ?? 'medium';
  Future<void> setBlurIntensity(String v) => _p.setString(_keyBlurIntensity, v);

  bool get clearOnClose => _p.getBool(_keyClearOnClose) ?? false;
  Future<void> setClearOnClose(bool v) => _p.setBool(_keyClearOnClose, v);

  List<String> get cookieWhitelist => _p.getStringList(_keyCookieWhitelist) ?? [];
  Future<void> setCookieWhitelist(List<String> v) => _p.setStringList(_keyCookieWhitelist, v);

  bool get siteIsolation => _p.getBool(_keySiteIsolation) ?? false;
  Future<void> setSiteIsolation(bool v) => _p.setBool(_keySiteIsolation, v);

  // ── Historial de URLs ───────────────────────────────────
  static const String _keyHistory = 'url_history';

  List<String> get history {
    return _p.getStringList(_keyHistory) ?? [];
  }

  Future<void> addToHistory(String url) async {
    await addToHistoryWithTitle('', url);
  }

  Future<void> addToHistoryWithTitle(String title, String url) async {
    final list = history;
    list.removeWhere((item) {
      if (item == url) return true;
      if (item.contains('"url":"$url"')) return true;
      return false;
    });
    final Map<String, dynamic> map = {
      'title': title,
      'url': url,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    list.insert(0, jsonEncode(map));
    if (list.length > 200) list.removeLast();
    await _p.setStringList(_keyHistory, list);
  }

  Future<void> clearHistory() => _p.remove(_keyHistory);


  // ── Favoritos ───────────────────────────────────────────
  static const String _keyBookmarks = 'bookmarks';

  List<String> get bookmarks {
    return _p.getStringList(_keyBookmarks) ?? [];
  }

  Future<void> addBookmark(String url) async {
    await addBookmarkWithTitle('', url);
  }

  Future<void> addBookmarkWithTitle(String title, String url, {int? lastModified}) async {
    final list = bookmarks;
    int? existingTime;
    String? duplicateItem;

    for (final item in list) {
      try {
        final Map<String, dynamic> bMap = jsonDecode(item);
        if (bMap['url'] == url) {
          duplicateItem = item;
          existingTime = int.tryParse(bMap['last_modified']?.toString() ?? '');
          break;
        }
      } catch (_) {}
    }

    final targetTime = lastModified ?? DateTime.now().millisecondsSinceEpoch;
    if (existingTime != null && existingTime >= targetTime) {
      return; // Local is newer or equal, ignore
    }

    if (duplicateItem != null) {
      list.remove(duplicateItem);
    }

    final Map<String, String> map = {
      'title': title,
      'url': url,
      'last_modified': targetTime.toString()
    };
    list.add(jsonEncode(map));
    await _p.setStringList(_keyBookmarks, list);
  }

  Future<void> removeBookmark(String url) async {
    final list = bookmarks;
    list.removeWhere((item) {
      if (item == url) return true;
      if (item.contains('"url":"$url"')) return true;
      return false;
    });
    await _p.setStringList(_keyBookmarks, list);
  }

  bool isBookmarked(String url) {
    return bookmarks.any((item) {
      if (item == url) return true;
      if (item.contains('"url":"$url"')) return true;
      return false;
    });
  }
  // -- Getters/Setters: Barra de favoritos --
  bool get showBookmarksBar =>
      _p.getBool(_keyShowBookmarksBar) ?? true; // ON por defecto
  Future<void> setShowBookmarksBar(bool v) async {
    await _p.setBool(_keyShowBookmarksBar, v);
    await updateSettingsTimestamp();
  }

  Future<void> updateBookmark(String oldUrl, String newTitle, String newUrl) async {
    final list = bookmarks;
    list.removeWhere((item) {
      if (item == oldUrl) return true;
      if (item.contains('"url":"$oldUrl"')) return true;
      return false;
    });
    final Map<String, String> map = {'title': newTitle, 'url': newUrl};
    list.add(jsonEncode(map));
    await _p.setStringList(_keyBookmarks, list);
  }

  // -- Getters/Setters: Geolocalizacion Manual --
  bool get manualLocationEnabled => _p.getBool(_keyManualLocationEnabled) ?? false;
  Future<void> setManualLocationEnabled(bool v) => _p.setBool(_keyManualLocationEnabled, v);

  String get manualLocationCity => _p.getString(_keyManualLocationCity) ?? 'Manizales';
  Future<void> setManualLocationCity(String v) => _p.setString(_keyManualLocationCity, v);

  double get manualLocationLatitude => _p.getDouble(_keyManualLocationLatitude) ?? 5.0675;
  Future<void> setManualLocationLatitude(double v) => _p.setDouble(_keyManualLocationLatitude, v);

  double get manualLocationLongitude => _p.getDouble(_keyManualLocationLongitude) ?? -75.5100;
  Future<void> setManualLocationLongitude(double v) => _p.setDouble(_keyManualLocationLongitude, v);

  // ── Métodos genéricos para otros servicios ───────────────
  String? getString(String key) => _p.getString(key);
  Future<void> setString(String key, String val) => _p.setString(key, val);
  bool? getBool(String key) => _p.getBool(key);
  Future<void> setBool(String key, bool val) => _p.setBool(key, val);
  List<String>? getStringList(String key) => _p.getStringList(key);
  Future<void> setStringList(String key, List<String> val) => _p.setStringList(key, val);

  // ── Sincronizacion / Metadata ────────────────────────────
  int get settingsLastModified => _p.getInt('settings_last_modified') ?? 0;
  Future<void> setSettingsLastModified(int v) => _p.setInt('settings_last_modified', v);
  Future<void> updateSettingsTimestamp() => setSettingsLastModified(DateTime.now().millisecondsSinceEpoch);

  Future<int> getLastSyncTimestamp() async {
    return _p.getInt('settings_last_modified') ?? 0;
  }

  // ── Ajustes v1.7.0 ───────────────────────────────────────
  bool get passwordProtectionEnabled => _p.getBool('password_protection_enabled') ?? false;
  Future<void> setPasswordProtectionEnabled(bool v) async {
    await _p.setBool('password_protection_enabled', v);
    await updateSettingsTimestamp();
  }

  int get passwordGracePeriodMinutes => _p.getInt('password_grace_period_minutes') ?? 5;
  Future<void> setPasswordGracePeriodMinutes(int v) async {
    await _p.setInt('password_grace_period_minutes', v);
    await updateSettingsTimestamp();
  }

  bool get passwordCustomPinOnly => _p.getBool('password_custom_pin_only') ?? false;
  Future<void> setPasswordCustomPinOnly(bool v) async {
    await _p.setBool('password_custom_pin_only', v);
    await updateSettingsTimestamp();
  }

  String get passwordCustomPinHash => _p.getString('password_custom_pin_hash') ?? '';
  Future<void> setPasswordCustomPinHash(String v) async {
    await _p.setString('password_custom_pin_hash', v);
    await updateSettingsTimestamp();
  }

  bool get tabHibernateEnabled => _p.getBool('tab_hibernate_enabled') ?? true;
  Future<void> setTabHibernateEnabled(bool v) async {
    await _p.setBool('tab_hibernate_enabled', v);
    await updateSettingsTimestamp();
  }

  bool get adaptiveThemeEnabled => _p.getBool('adaptive_theme_enabled') ?? true;
  Future<void> setAdaptiveThemeEnabled(bool v) async {
    await _p.setBool('adaptive_theme_enabled', v);
    await updateSettingsTimestamp();
  }

  String get secureDnsMode => _p.getString('secure_dns_mode') ?? 'off';
  Future<void> setSecureDnsMode(String v) async {
    await _p.setString('secure_dns_mode', v);
    await updateSettingsTimestamp();
  }

  String get performanceProfile => _p.getString('performance_profile') ?? 'auto';
  Future<void> setPerformanceProfile(String v) async {
    await _p.setString('performance_profile', v);
    await updateSettingsTimestamp();
  }

  bool get performanceSettingsModified => _p.getBool('performance_settings_modified') ?? false;
  Future<void> setPerformanceSettingsModified(bool v) async {
    await _p.setBool('performance_settings_modified', v);
    await updateSettingsTimestamp();
  }

  bool get performanceProfileBannerDismissed => _p.getBool('performance_profile_banner_dismissed') ?? false;
  Future<void> setPerformanceProfileBannerDismissed(bool v) async {
    await _p.setBool('performance_profile_banner_dismissed', v);
    await updateSettingsTimestamp();
  }

  bool get hardwareBannerShownV170 => _p.getBool('hardware_banner_shown_v170') ?? false;
  Future<void> setHardwareBannerShownV170(bool v) async {
    await _p.setBool('hardware_banner_shown_v170', v);
    await updateSettingsTimestamp();
  }

  bool get autofillEnabled => _p.getBool('autofill_enabled') ?? true;
  Future<void> setAutofillEnabled(bool v) async {
    await _p.setBool('autofill_enabled', v);
    await updateSettingsTimestamp();
  }

  bool get autofillDisableInIncognito => _p.getBool('autofill_disable_in_incognito') ?? true;
  Future<void> setAutofillDisableInIncognito(bool v) async {
    await _p.setBool('autofill_disable_in_incognito', v);
    await updateSettingsTimestamp();
  }

  List<String> get autofillExcludedDomains => _p.getStringList('autofill_excluded_domains') ?? [];
  Future<void> setAutofillExcludedDomains(List<String> domains) async {
    await _p.setStringList('autofill_excluded_domains', domains);
    await updateSettingsTimestamp();
  }

  Future<void> addAutofillExcludedDomain(String domain) async {
    final list = autofillExcludedDomains.toList();
    if (!list.contains(domain)) {
      list.add(domain);
      await setAutofillExcludedDomains(list);
    }
  }

  Future<void> removeAutofillExcludedDomain(String domain) async {
    final list = autofillExcludedDomains.toList();
    if (list.contains(domain)) {
      list.remove(domain);
      await setAutofillExcludedDomains(list);
    }
  }

  // ── Bloqueo Cosmético ────────────────────────────────────
  static const String _keyCosmeticEnabled        = 'cosmetic_block_enabled';
  static const String _keyCosmeticUseOfficial    = 'cosmetic_use_official';
  static const String _keyCosmeticUserRules      = 'cosmetic_user_rules';
  static const String _keyCosmeticExcluded       = 'cosmetic_excluded_domains';

  bool get cosmeticBlockEnabled => _p.getBool(_keyCosmeticEnabled) ?? true;
  Future<void> setCosmeticBlockEnabled(bool v) async {
    await _p.setBool(_keyCosmeticEnabled, v);
    await updateSettingsTimestamp();
  }

  bool get cosmeticUseOfficialRules => _p.getBool(_keyCosmeticUseOfficial) ?? true;
  Future<void> setCosmeticUseOfficialRules(bool v) async {
    await _p.setBool(_keyCosmeticUseOfficial, v);
    await updateSettingsTimestamp();
  }

  String get cosmeticUserRules => _p.getString(_keyCosmeticUserRules) ?? '';
  Future<void> setCosmeticUserRules(String v) async {
    await _p.setString(_keyCosmeticUserRules, v);
    await updateSettingsTimestamp();
  }

  List<String> get cosmeticExcludedDomains =>
      _p.getStringList(_keyCosmeticExcluded) ?? [];
  Future<void> setCosmeticExcludedDomains(List<String> v) async {
    await _p.setStringList(_keyCosmeticExcluded, v);
    await updateSettingsTimestamp();
  }

  Future<void> addCosmeticExcludedDomain(String domain) async {
    final list = cosmeticExcludedDomains.toList();
    if (!list.contains(domain)) {
      list.add(domain);
      await setCosmeticExcludedDomains(list);
    }
  }

  Future<void> removeCosmeticExcludedDomain(String domain) async {
    final list = cosmeticExcludedDomains.toList();
    if (list.remove(domain)) {
      await setCosmeticExcludedDomains(list);
    }
  }


  Future<void> migrateCookiesToEncrypted() async {
    final migrated = _p.getBool('cookies_migrated_v170') ?? false;
    if (migrated) return;

    try {
      final keys = _p.getKeys();
      for (final key in keys) {
        if (key.startsWith('session_data_')) {
          final domain = key.replaceFirst('session_data_', '');
          final rawValue = _p.getString(key);
          if (rawValue != null && rawValue.isNotEmpty) {
            try {
              // En v1.6.0 se codificaban en base64 plano sin cifrar.
              final decodedBytes = base64Decode(rawValue);
              final decodedText = utf8.decode(decodedBytes);
              // Si la decodificación fue exitosa y parece un JSON de cookies, lo ciframos nativamente.
              if (decodedText.startsWith('[') || decodedText.startsWith('{')) {
                final encrypted = await PasswordService.instance.encryptText(decodedText);
                if (encrypted != null) {
                  await _p.setString(key, encrypted);
                  debugPrint('[StorageService] Migradas cookies de sesion para $domain a cifrado nativo.');
                }
              }
            } catch (e) {
              // Si falla (ej. ya estaba cifrado o inválido), omitimos sin romper nada.
              debugPrint('[StorageService] Omitiendo migracion de cookies para $domain: $e');
            }
          }
        }
      }
      await _p.setBool('cookies_migrated_v170', true);
    } catch (e) {
      debugPrint('[StorageService] Error durante la migracion de cookies: $e');
    }
  }

  // ── Reset total ─────────────────────────────────────────
  Future<void> clearAll() => _p.clear();
}
