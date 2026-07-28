// ==============================================================
// DulceNav - blocklist_manager.dart v1.2.1
// Gestiona listas de bloqueo de anuncios y rastreadores.
// Descarga formato ABP (EasyList/AdGuard), parsea y persiste
// en SQLite via sqflite_common_ffi (compatible con Windows).
// Actualizacion automatica cada 24 horas en segundo plano.
//
// OPTIMIZACIONES v1.2.1:
//   - Parser mas estricto: reduce falsos positivos
//   - Insercion en lotes mas pequenos (200 filas) para no bloquear UI
//   - Limite de reglas por fuente (100k max) para no saturar memoria
//   - Carga desde DB en isolate separado (no congela UI)
//   - Validacion de dominios mejorada
// ==============================================================

import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'cosmetic_blocker.dart';
import 'cosmetic_rule.dart';

class BlocklistManager extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────
  BlocklistManager._();
  static final BlocklistManager instance = BlocklistManager._();

  // ── Estado publico ─────────────────────────────────────────

  // Dominios exactos bloqueados: O(1) lookup
  HashSet<String> _blockedDomains = HashSet<String>();
  HashSet<String> get blockedDomains => _blockedDomains;

  // Patrones de dominio (sin subdominios): O(1) lookup
  HashSet<String> _blockedPatterns = HashSet<String>();
  HashSet<String> get blockedPatterns => _blockedPatterns;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _totalRules = 0;
  int get totalRules => _totalRules;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  String _statusMessage = 'No inicializado';
  String get statusMessage => _statusMessage;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ── Base de datos ──────────────────────────────────────────
  Database? _db;
  static const String _dbName   = 'dulcenav_blocklist.db';
  static const String _tblRules = 'block_rules';
  static const String _tblMeta  = 'meta';

  // Maximo de reglas por fuente (evita saturar SQLite y RAM)
  static const int _maxRulesPerSource = 80000;

  // ── Fuentes de listas ABP ──────────────────────────────────
  static const List<_BLSource> _sources = <_BLSource>[
    _BLSource(
      name: 'EasyList',
      url: 'https://easylist.to/easylist/easylist.txt',
    ),
    _BLSource(
      name: 'EasyPrivacy',
      url: 'https://easylist.to/easylist/easyprivacy.txt',
    ),
    _BLSource(
      name: 'AdGuard Mobile',
      url: 'https://filters.adtidy.org/android/filters/15_optimized.txt',
    ),
  ];

  // ── INICIALIZACION ─────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _setStatus('Inicializando base de datos...');

    // Inicializar FFI para escritorio (Windows, Linux, macOS)
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _db = await openDatabase(
      _dbName,
      version: 2,
      onCreate: _onCreateDB,
      onUpgrade: _onUpgradeDB,
    );

    // Carga asincrona real en segundo plano sin bloquear el hilo principal
    _loadFromDatabaseBackground().then((_) {
      _initialized = true;
      if (_totalRules == 0) {
        // Primera ejecucion: descargar listas
        _setStatus('Primera ejecucion: descargando listas de bloqueo...');
        unawaited(updateAllLists());
      } else {
        _setStatus('$_totalRules reglas activas.');
        _scheduleAutoUpdate();
      }
    });
  }

  Future<void> _loadFromDatabaseBackground() async {
    try {
      final dbPath = _db!.path;
      final result = await compute(_loadDatabaseWork, _DbLoadParams(dbPath));

      _blockedDomains = HashSet<String>.from(result.domains);
      _blockedPatterns = HashSet<String>.from(result.patterns);
      _totalRules = _blockedDomains.length + _blockedPatterns.length;

      if (result.lastUpdatedStr != null) {
        _lastUpdated = DateTime.tryParse(result.lastUpdatedStr!);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[BlocklistManager] Error al cargar base de datos en Isolate: $e');
      // Fallback en el main thread si hay error
      await _loadFromDatabase();
    }
  }

  // ── Crear tablas ───────────────────────────────────────────

  Future<void> _onCreateDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tblRules (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        domain   TEXT    NOT NULL,
        is_pattern INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // Indice para busquedas rapidas por dominio
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_domain ON $_tblRules (domain)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tblMeta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgradeDB(Database db, int oldV, int newV) async {
    // Migracion limpia si la version cambio
    await db.execute('DROP TABLE IF EXISTS $_tblRules');
    await db.execute('DROP TABLE IF EXISTS $_tblMeta');
    await _onCreateDB(db, newV);
  }

  // ── Cargar desde base de datos ─────────────────────────────

  Future<void> _loadFromDatabase() async {
    if (_db == null) return;

    final List<Map<String, dynamic>> rows = await _db!.query(
      _tblRules,
      columns: <String>['domain', 'is_pattern'],
    );

    final HashSet<String> domains  = HashSet<String>();
    final HashSet<String> patterns = HashSet<String>();

    for (final Map<String, dynamic> row in rows) {
      final String domain    = row['domain'] as String;
      final int    isPattern = row['is_pattern'] as int;
      if (isPattern == 1) {
        patterns.add(domain);
      } else {
        domains.add(domain);
      }
    }

    _blockedDomains  = domains;
    _blockedPatterns = patterns;
    _totalRules      = domains.length + patterns.length;

    // Leer fecha de ultima actualizacion
    final List<Map<String, dynamic>> meta = await _db!.query(
      _tblMeta,
      where: 'key = ?',
      whereArgs: <String>['last_updated'],
    );
    if (meta.isNotEmpty) {
      _lastUpdated = DateTime.tryParse(meta.first['value'] as String? ?? '');
    }

    notifyListeners();
  }

  // ── ACTUALIZAR LISTAS ──────────────────────────────────────
  // Descarga, parsea y guarda las 3 fuentes en SQLite.

  Future<void> updateAllLists() async {
    if (_isLoading) return;
    _isLoading = true;
    _setStatus('Actualizando listas de bloqueo...');

    final HashSet<String> allDomains  = HashSet<String>();
    final HashSet<String> allPatterns = HashSet<String>();
    final List<_CosmeticEntry> allCosmeticRules = [];

    for (final _BLSource source in _sources) {
      try {
        _setStatus('Descargando ${source.name}...');
        final http.Response resp = await http
            .get(Uri.parse(source.url))
            .timeout(const Duration(seconds: 45));

        if (resp.statusCode == 200) {
          // Procesamiento ABP en Isolate de Dart en segundo plano (no jank)
          final parseResult = await compute(
            _parseABPWork,
            _ParseParams(resp.body, _maxRulesPerSource),
          );
          allDomains.addAll(parseResult.domains);
          allPatterns.addAll(parseResult.patterns);
          allCosmeticRules.addAll(parseResult.cosmeticRules);
          
          final count = parseResult.domains.length + parseResult.patterns.length;
          _setStatus('${source.name}: $count reglas validas.');
        } else {
          _setStatus('${source.name}: error HTTP ${resp.statusCode}');
        }
      } on TimeoutException {
        _setStatus('${source.name}: tiempo de espera agotado.');
        debugPrint('[BlocklistManager] Timeout en ${source.name}');
      } catch (e) {
        _setStatus('${source.name}: error de red.');
        debugPrint('[BlocklistManager] Error en ${source.name}: $e');
      }
    }

    if (allDomains.isNotEmpty || allPatterns.isNotEmpty) {
      await _saveToDatabase(allDomains, allPatterns);
      _blockedDomains  = allDomains;
      _blockedPatterns = allPatterns;
      _totalRules      = allDomains.length + allPatterns.length;
      _lastUpdated     = DateTime.now();
      _setStatus('$_totalRules reglas activas tras actualizacion.');

      // Pasar reglas cosméticas a CosmeticBlocker (capa cosmética independiente)
      if (allCosmeticRules.isNotEmpty) {
        final List<CosmeticRule> converted = allCosmeticRules
            .map((e) => CosmeticRule(
                  selector: e.selector,
                  domain: e.domain,
                  isAdvanced: e.isAdvanced,
                ))
            .toList();
        unawaited(CosmeticBlocker.instance.loadParsedRules(converted));
        debugPrint('[BlocklistManager] ${converted.length} reglas cosméticas enviadas a CosmeticBlocker.');
      }
    } else {
      _setStatus('No se obtuvieron reglas. Se mantiene la lista anterior.');
    }

    _isLoading = false;
    notifyListeners();
    _scheduleAutoUpdate();
  }

  // ── PARSER ABP ─────────────────────────────────────────────
  // Soporta:
  //   ||dominio.com^          -> dominio + subdominios bloqueados
  //   dominio.com             -> dominio exacto bloqueado
  // Ignora:
  //   ! comentarios
  //   ## reglas cosmeticas (CSS)
  //   @@ lista blanca
  //   /regex/                 -> expresiones regulares complejas
  //   Reglas con opciones de tipo $script,$image (se extraen igual)


  // ── GUARDAR EN BASE DE DATOS ───────────────────────────────

  Future<void> _saveToDatabase(
    HashSet<String> domains,
    HashSet<String> patterns,
  ) async {
    if (_db == null) return;

    await _db!.transaction((Transaction txn) async {
      await txn.delete(_tblRules);

      // Insertar en lotes de 200 (no bloquea el isolate)
      await _insertBatch(txn, domains.toList(),  isPattern: 0);
      await _insertBatch(txn, patterns.toList(), isPattern: 1);

      await txn.insert(
        _tblMeta,
        <String, dynamic>{
          'key':   'last_updated',
          'value': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _insertBatch(
    Transaction txn,
    List<String> items, {
    required int isPattern,
  }) async {
    const int batchSize = 200;
    for (int i = 0; i < items.length; i += batchSize) {
      final int end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final Batch batch = txn.batch();
      for (final String item in items.sublist(i, end)) {
        batch.insert(
          _tblRules,
          <String, dynamic>{'domain': item, 'is_pattern': isPattern},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  // ── AUTO-ACTUALIZACION ─────────────────────────────────────

  Timer? _updateTimer;

  void _scheduleAutoUpdate() {
    _updateTimer?.cancel();
    final DateTime now = DateTime.now();
    const Duration interval = Duration(hours: 24);

    Duration delay;
    if (_lastUpdated == null || now.difference(_lastUpdated!) >= interval) {
      // Actualizar en 10 segundos (la UI ya termino de cargar)
      delay = const Duration(seconds: 10);
    } else {
      delay = interval - now.difference(_lastUpdated!);
    }

    _updateTimer = Timer(delay, () => unawaited(updateAllLists()));
  }

  // ── UTILIDADES ─────────────────────────────────────────────

  void _setStatus(String msg) {
    _statusMessage = msg;
    notifyListeners();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _db?.close();
    super.dispose();
  }
}

// Modelo de fuente
class _BLSource {
  final String name;
  final String url;
  const _BLSource({required this.name, required this.url});
}

// ── AUXILIARES DE AISLAMIENTO (ISOLATES DE DART) ────────────────

class _DbLoadParams {
  final String dbPath;
  _DbLoadParams(this.dbPath);
}

class _DbLoadResult {
  final List<String> domains;
  final List<String> patterns;
  final String? lastUpdatedStr;
  _DbLoadResult(this.domains, this.patterns, this.lastUpdatedStr);
}

Future<_DbLoadResult> _loadDatabaseWork(_DbLoadParams params) async {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final Database db = await openDatabase(params.dbPath, readOnly: true);
  final List<Map<String, dynamic>> rows = await db.query(
    'block_rules',
    columns: <String>['domain', 'is_pattern'],
  );

  final List<String> domains = [];
  final List<String> patterns = [];

  for (final Map<String, dynamic> row in rows) {
    final String domain = row['domain'] as String;
    final int isPattern = row['is_pattern'] as int;
    if (isPattern == 1) {
      patterns.add(domain);
    } else {
      domains.add(domain);
    }
  }

  String? lastUpdatedStr;
  try {
    final List<Map<String, dynamic>> meta = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: <String>['last_updated'],
    );
    if (meta.isNotEmpty) {
      lastUpdatedStr = meta.first['value'] as String?;
    }
  } catch (_) {}

  await db.close();
  return _DbLoadResult(domains, patterns, lastUpdatedStr);
}

class _ParseParams {
  final String content;
  final int maxRules;
  _ParseParams(this.content, this.maxRules);
}

// Regla cosmética extraída en el isolate de parseo.
// Transporta los datos mínimos necesarios al hilo principal.
class _CosmeticEntry {
  final String? domain;
  final String selector;
  final bool isAdvanced;
  _CosmeticEntry(this.domain, this.selector, {this.isAdvanced = false});
}

class _ParseResult {
  final List<String> domains;
  final List<String> patterns;
  // Reglas cosméticas (##, #?#) extraídas para CosmeticBlocker
  final List<_CosmeticEntry> cosmeticRules;
  _ParseResult(this.domains, this.patterns, [this.cosmeticRules = const []]);
}

_ParseResult _parseABPWork(_ParseParams params) {
  final List<String> domains = [];
  final List<String> patterns = [];
  final List<_CosmeticEntry> cosmeticRules = [];
  final List<String> lines = params.content.split('\n');

  // Máximo de reglas cosméticas extraídas por fuente (rendimiento)
  const int maxCosmetic = 20000;

  int count = 0;
  for (final String raw in lines) {
    if (count >= params.maxRules) break;

    final String line = raw.trim();

    if (line.isEmpty ||
        line.startsWith('!') ||
        line.startsWith('[') ||
        line.startsWith('#')) {
      continue;
    }

    // Reglas cosméticas: extraer en lugar de ignorar
    if (line.contains('##') || line.contains('#?#')) {
      // Saltar lista blanca cosmética
      if (line.contains('#@#')) continue;
      if (cosmeticRules.length < maxCosmetic) {
        _extractCosmeticEntry(line, cosmeticRules);
      }
      continue; // No son reglas de red
    }

    if (line.startsWith('@@')) continue;

    if (line.startsWith('/') && line.endsWith('/')) continue;

    if (line.startsWith('||')) {
      final String raw2 = line.substring(2);
      final String domain = _cleanRuleWork(raw2);
      if (_isValidDomainWork(domain)) {
        patterns.add(domain);
        count++;
      }
    } else if (!line.startsWith('|') &&
               !line.startsWith('.') &&
               !line.startsWith('*') &&
               !line.startsWith('/')) {
      final String domain = _cleanRuleWork(line);
      if (_isValidDomainWork(domain)) {
        domains.add(domain);
        count++;
      }
    }
  }

  return _ParseResult(domains, patterns, cosmeticRules);
}

// Extrae una regla cosmética de una línea ABP y la agrega a la lista.
void _extractCosmeticEntry(String line, List<_CosmeticEntry> out) {
  final bool isAdvanced = line.contains('#?#');
  final String sep = isAdvanced ? '#?#' : '##';
  final int idx = line.indexOf(sep);
  if (idx < 0) return;

  final String domainPart   = line.substring(0, idx).trim();
  final String selectorPart = line.substring(idx + sep.length).trim();

  if (selectorPart.isEmpty || selectorPart.length > 500) return;

  if (domainPart.isEmpty) {
    out.add(_CosmeticEntry(null, selectorPart, isAdvanced: isAdvanced));
  } else {
    for (final String d in domainPart.split(',')) {
      final String domain = d.trim().toLowerCase();
      if (domain.isNotEmpty && domain.contains('.')) {
        out.add(_CosmeticEntry(domain, selectorPart, isAdvanced: isAdvanced));
      }
    }
  }
}

String _cleanRuleWork(String rule) {
  String d = rule;
  final int dollar = d.indexOf('\$');
  if (dollar != -1) d = d.substring(0, dollar);
  final int slash = d.indexOf('/');
  if (slash != -1) d = d.substring(0, slash);
  d = d.replaceAll('^', '').replaceAll('*', '').trim();
  return d.toLowerCase();
}

bool _isValidDomainWork(String d) {
  if (d.length < 4 || d.length > 253) return false;
  if (!d.contains('.')) return false;
  final RegExp valid = RegExp(r'^[a-z0-9.\-]+$');
  if (!valid.hasMatch(d)) return false;
  final String tld = d.split('.').last;
  if (tld.isEmpty || tld.length < 2) return false;
  return true;
}
