// ============================================================
// DulceNav — app_config.dart
// Configuraciones globales. Aquí se centralizan todos los
// parámetros que controlan el comportamiento de la app.
// ============================================================

class AppConfig {
  AppConfig._(); // No instanciable

  // ─── IDENTIDAD ───────────────────────────────────────────
  static const String appName = 'DulceNav';
  static const String appVersion = '1.8.1';
  static const String ecosystemName = 'Dulce Universe';
  static const String ecosystemUrl = 'https://dulceapps.lovable.app';

  // ─── PÁGINA DE INICIO ────────────────────────────────────
  /// URL que se carga al iniciar la app o presionar Home
  static const String homeUrl = 'about:dulcenav';

  /// Motor de búsqueda por defecto
  static const String defaultSearchEngine = 'https://duckduckgo.com/?q=';

  // ─── GESTIÓN DE PESTAÑAS ─────────────────────────────────
  /// Máximo de pestañas permitidas simultáneamente
  static const int maxTabs = 20;

  /// Tiempo de inactividad antes de hibernar una pestaña (minutos)
  static const int tabHibernateMinutes = 5;

  /// Tiempo de inactividad antes de descargar recursos de pestaña (minutos)
  static const int tabUnloadMinutes = 15;

  // ─── RENDIMIENTO / MEMORIA ───────────────────────────────
  /// Umbral de uso de RAM para activar limpieza agresiva (MB)
  static const int memoryCleanupThresholdMB = 400;

  /// Tiempo de gracia antes de limpiar caché al minimizar (ms)
  static const int minimizeCleanupDelayMs = 2000;

  /// Tamaño máximo del caché de imágenes en RAM (MB)
  static const int imageCacheMaxMB = 50;

  // ─── SEGURIDAD ───────────────────────────────────────────
  /// Bloqueo activado por defecto (NO CAMBIAR)
  static const bool adBlockEnabledByDefault = true;

  /// Protección de rastreadores activada por defecto
  static const bool trackingProtectionByDefault = true;

  /// Protección anti-phishing activada por defecto
  static const bool antiPhishingByDefault = true;

  /// Intervalo de actualización de listas de bloqueo (horas)
  static const int blocklistUpdateIntervalHours = 24;

  // URLs de listas de bloqueo (se descargan en background)
  static const List<String> blocklistUrls = [
    // EasyList — anuncios generales
    'https://easylist.to/easylist/easylist.txt',
    // EasyPrivacy — rastreadores
    'https://easylist.to/easylist/easyprivacy.txt',
    // AdGuard Mobile — optimizado para móvil/apps
    'https://filters.adtidy.org/android/filters/11_optimized.txt',
    // MalwareDomains — sitios maliciosos
    'https://raw.githubusercontent.com/nickcook-io/malwaredomains/master/domains.txt',
  ];

  // ─── IA INTEGRADA (DULCEMIND LOCAL) ─────────────────────
  /// Desactivada por defecto — REGLA DE ORO
  static const bool aiEnabledByDefault = false;

  /// Modelos GGUF oficiales descargables en 1 clic desde HuggingFace
  static const Map<String, String> llama3_2_1b_config = {
    'id': 'llama-3.2-1b-instruct',
    'name': 'Llama 3.2 1B Instruct (Q4_K_M)',
    'filename': 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    'url': 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    'size': '1.2 GB',
    'min_ram': '≥ 4 GB RAM',
    'sha256': 'a1352f205c0bb63212ae1a6ff8bf544f8064d1f5e8bd9b70b55edcd7c6df4a56',
  };

  static const Map<String, String> qwen2_5_1_5b_config = {
    'id': 'qwen-2.5-1.5b-instruct',
    'name': 'Qwen 2.5 1.5B Instruct (Q4_K_M)',
    'filename': 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    'url': 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    'size': '1.3 GB',
    'min_ram': '≥ 4 GB RAM',
    'sha256': 'b2234f205c0bb63212ae1a6ff8bf544f8064d1f5e8bd9b70b55edcd7c6df4a57',
  };

  /// Inactividad máxima antes de descargar el modelo de memoria RAM (minutos)
  static const int aiRamUnloadMinutes = 5;

  // ─── UI ──────────────────────────────────────────────────
  /// Duración de animaciones (reducida para bajo consumo)
  static const Duration animationFast = Duration(milliseconds: 120);
  static const Duration animationNormal = Duration(milliseconds: 200);

  /// Altura de la barra de navegación inferior
  static const double navBarHeight = 52.0;

  /// Altura de la barra de dirección
  static const double addressBarHeight = 46.0;

  // ─── AVISO LEGAL OBLIGATORIO ─────────────────────────────
  static const String legalDisclaimer =
      'DulceNav es una herramienta de navegación. No aloja, almacena ni '
      'distribuye contenido. Protegemos tu conexión; el usuario es '
      'responsable de su navegación.';
}
