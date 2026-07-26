// ==============================================================
// DulceNav - cosmetic_blocker.dart v1.0.0
// Motor de bloqueo cosmético de anuncios (CSS hiding layer).
//
// ESTRATEGIA:
//   - Lee las mismas listas ABP que BlocklistManager.
//   - Parsea SOLO las líneas cosméticas (##, #?#).
//   - Las indexa por dominio en memoria para búsqueda O(1).
//   - Persiste en SQLite propio (dulcenav_cosmetic.db).
//   - Genera un snippet JS con los selectores del dominio actual.
//   - El JS es inyectado por los WebViews en onLoadStop.
//
// INDEPENDENCIA:
//   - NO toca ad_blocker.dart ni blocklist_manager.dart.
//   - Usa su propia base de datos separada.
//   - Se inicializa de forma independiente.
//
// LÍMITES DE SEGURIDAD:
//   - Máx. 500 selectores enviados al JS por página.
//   - MutationObserver solo observa addedNodes.
//   - El JS solo usa display:none — nunca toca eventos ni valores.
// ==============================================================

import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/services/storage_service.dart';
import '../../core/constants/webview_scripts.dart';
import 'cosmetic_rule.dart';

class CosmeticBlocker extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────
  CosmeticBlocker._();
  static final CosmeticBlocker instance = CosmeticBlocker._();

  // ── Estado interno ─────────────────────────────────────────
  // Reglas globales (aplican a todos los dominios)
  final List<String> _globalSelectors = [];

  // Reglas por dominio: { 'youtube.com': ['.ytp-ad-module', ...] }
  final HashMap<String, List<String>> _byDomain = HashMap<String, List<String>>();

  // Reglas personalizadas del usuario (parseadas en memoria)
  final List<String> _userGlobalSelectors = [];
  final HashMap<String, List<String>> _userByDomain = HashMap<String, List<String>>();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  int _totalCosmeticRules = 0;
  int get totalCosmeticRules => _totalCosmeticRules;

  // ── Base de datos propia ───────────────────────────────────
  Database? _db;
  static const String _dbName    = 'dulcenav_cosmetic.db';
  static const String _tblRules  = 'cosmetic_rules';
  static const int    _dbVersion = 1;

  // Límite de reglas por página (rendimiento)
  static const int _maxSelectorsPerPage = 500;

  // ── Getters de configuración (delegados a StorageService) ──
  bool get isEnabled          => StorageService.instance.cosmeticBlockEnabled;
  bool get useOfficialRules   => StorageService.instance.cosmeticUseOfficialRules;

  // ── INICIALIZACIÓN ─────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    // FFI para escritorio
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _db = await openDatabase(
      _dbName,
      version: _dbVersion,
      onCreate: _onCreateDB,
    );

    await _loadFromDatabase();
    _parseUserRules(StorageService.instance.cosmeticUserRules);
    _initialized = true;
    notifyListeners();
  }

  // ── CREAR TABLA ────────────────────────────────────────────

  Future<void> _onCreateDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tblRules (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        domain   TEXT,
        selector TEXT NOT NULL,
        is_advanced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cosmetic_domain ON $_tblRules (domain)',
    );
  }

  // ── CARGAR DESDE DB ────────────────────────────────────────

  Future<void> _loadFromDatabase() async {
    if (_db == null) return;

    final List<Map<String, dynamic>> rows = await _db!.query(
      _tblRules,
      columns: <String>['domain', 'selector'],
    );

    _globalSelectors.clear();
    _byDomain.clear();
    int count = 0;

    for (final Map<String, dynamic> row in rows) {
      final String? domain   = row['domain'] as String?;
      final String  selector = row['selector'] as String;

      if (domain == null || domain.isEmpty) {
        _globalSelectors.add(selector);
      } else {
        _byDomain.putIfAbsent(domain, () => []).add(selector);
      }
      count++;
    }

    _totalCosmeticRules = count;
    debugPrint('[CosmeticBlocker] Cargadas $_totalCosmeticRules reglas cosméticas desde DB.');
  }

  // ── CARGAR REGLAS DE LISTAS ABP (llamado por blocklist_manager) ────

  /// Recibe reglas cosméticas parseadas por BlocklistManager desde su isolate.
  /// Reemplaza todas las reglas oficiales en DB y en memoria.
  Future<void> loadParsedRules(List<CosmeticRule> rules) async {
    if (_db == null) return;

    await _db!.transaction((Transaction txn) async {
      // Borrar todas las reglas oficiales (las del usuario se guardan en SharedPreferences)
      await txn.delete(_tblRules);

      const int batchSize = 200;
      for (int i = 0; i < rules.length; i += batchSize) {
        final int end = (i + batchSize < rules.length) ? i + batchSize : rules.length;
        final Batch batch = txn.batch();
        for (final CosmeticRule rule in rules.sublist(i, end)) {
          batch.insert(
            _tblRules,
            <String, dynamic>{
              'domain':      rule.domain,
              'selector':    rule.selector,
              'is_advanced': rule.isAdvanced ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        await batch.commit(noResult: true);
      }
    });

    // Recargar en memoria
    await _loadFromDatabase();
    notifyListeners();
    debugPrint('[CosmeticBlocker] ${rules.length} reglas cosméticas actualizadas.');
  }

  // ── REGLAS DEL USUARIO ─────────────────────────────────────

  /// Parsea el texto multilínea de reglas personalizadas del usuario.
  void _parseUserRules(String rawText) {
    _userGlobalSelectors.clear();
    _userByDomain.clear();

    if (rawText.trim().isEmpty) return;

    for (final String line in rawText.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('!')) continue;
      _parseSingleCosmeticLine(trimmed, _userGlobalSelectors, _userByDomain);
    }
  }

  /// Actualiza las reglas personalizadas del usuario (persistencia + memoria).
  Future<void> updateUserRules(String rawText) async {
    await StorageService.instance.setCosmeticUserRules(rawText);
    _parseUserRules(rawText);
    notifyListeners();
  }

  // ── OBTENER REGLAS PARA UN DOMINIO ─────────────────────────

  /// Devuelve la lista combinada de selectores CSS (oficiales + usuario)
  /// para el dominio dado y sus padres. Limitada a [_maxSelectorsPerPage].
  List<String> getSelectorsForDomain(String domain) {
    if (!isEnabled) return const [];
    if (isExcludedDomain(domain)) return const [];

    final Set<String> selectors = <String>{};

    // 1. Reglas oficiales globales
    if (useOfficialRules) {
      selectors.addAll(_globalSelectors);
    }

    // 2. Reglas oficiales por dominio (dominio exacto y padres)
    if (useOfficialRules) {
      _addDomainSelectors(domain, _byDomain, selectors);
    }

    // 3. Reglas del usuario globales
    selectors.addAll(_userGlobalSelectors);

    // 4. Reglas del usuario por dominio
    _addDomainSelectors(domain, _userByDomain, selectors);

    // Respetar límite por página
    if (selectors.length > _maxSelectorsPerPage) {
      return selectors.take(_maxSelectorsPerPage).toList();
    }
    return selectors.toList();
  }

  void _addDomainSelectors(
    String domain,
    HashMap<String, List<String>> map,
    Set<String> target,
  ) {
    // Dominio exacto
    final exact = map[domain];
    if (exact != null) target.addAll(exact);

    // Dominio padre (sin subdominios)
    final parts = domain.split('.');
    for (int i = 1; i < parts.length - 1; i++) {
      final parent = parts.sublist(i).join('.');
      final parentRules = map[parent];
      if (parentRules != null) target.addAll(parentRules);
    }
  }

  // ── GENERAR SCRIPT JS ─────────────────────────────────────

  /// Genera el fragmento de código JavaScript que oculta los elementos
  /// del dominio dado. Devuelve cadena vacía si no hay reglas o está desactivado.
  String getCosmeticScript(String domain) {
    final List<String> selectors = getSelectorsForDomain(domain);
    if (selectors.isEmpty) return '';

    // Serializar selectores como array JS
    final StringBuffer sb = StringBuffer('[');
    for (int i = 0; i < selectors.length; i++) {
      // Escapar comillas simples en el selector
      final String escaped = selectors[i].replaceAll("'", "\\'");
      sb.write("'$escaped'");
      if (i < selectors.length - 1) sb.write(',');
    }
    sb.write(']');

    return '''
window.dulceCosmeticSelectors = $sb;
${WebViewScripts.cosmeticBlockScript}
''';
  }

  // ── EXCLUSIONES ────────────────────────────────────────────

  bool isExcludedDomain(String domain) {
    return StorageService.instance.cosmeticExcludedDomains.contains(domain);
  }

  Future<void> excludeDomain(String domain) async {
    await StorageService.instance.addCosmeticExcludedDomain(domain);
    notifyListeners();
  }

  Future<void> removeExclusion(String domain) async {
    await StorageService.instance.removeCosmeticExcludedDomain(domain);
    notifyListeners();
  }

  // ── UTILIDADES DE PARSEO ────────────────────────────────────

  /// Parsea una línea de lista ABP en formato cosmético.
  /// Retorna null si la línea no es una regla cosmética válida.
  static CosmeticRule? parseCosmeticLine(String line) {
    final List<String> globalDummy = [];
    final HashMap<String, List<String>> domainDummy = HashMap();
    _parseSingleCosmeticLine(line, globalDummy, domainDummy);
    if (globalDummy.isNotEmpty) {
      return CosmeticRule(selector: globalDummy.first);
    }
    if (domainDummy.isNotEmpty) {
      final entry = domainDummy.entries.first;
      if (entry.value.isNotEmpty) {
        return CosmeticRule(domain: entry.key, selector: entry.value.first);
      }
    }
    return null;
  }

  static void _parseSingleCosmeticLine(
    String line,
    List<String> globalList,
    HashMap<String, List<String>> domainMap,
  ) {
    // Detectar tipo de separador cosmético
    final bool isAdvanced = line.contains('#?#');
    final bool isHide     = line.contains('##') && !line.contains('#@#');

    if (!isHide && !isAdvanced) return;

    final String sep = isAdvanced ? '#?#' : '##';
    final int idx = line.indexOf(sep);
    if (idx < 0) return;

    final String domainPart   = line.substring(0, idx).trim();
    final String selectorPart = line.substring(idx + sep.length).trim();

    // Validar selector: debe tener contenido y no contener inyección peligrosa
    if (selectorPart.isEmpty) return;
    if (selectorPart.length > 500) return; // Selector anormalmente largo

    if (domainPart.isEmpty) {
      // Regla global
      globalList.add(selectorPart);
    } else {
      // Puede haber múltiples dominios separados por coma
      final List<String> domains = domainPart.split(',');
      for (final String d in domains) {
        final String domain = d.trim().toLowerCase();
        if (domain.isNotEmpty && domain.contains('.')) {
          domainMap.putIfAbsent(domain, () => []).add(selectorPart);
        }
      }
    }
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }
}
