// ============================================================
// DulceNav — app_strings.dart
// Textos de la interfaz, mensajes de seguridad y avisos legales.
// ============================================================

class AppStrings {
  AppStrings._();

  // ─── NAVEGACIÓN ──────────────────────────────────────────
  static const String searchHint = 'Busca o escribe una URL...';
  static const String newTab = 'Nueva pestaña';
  static const String closeTab = 'Cerrar pestaña';
  static const String settings = 'Ajustes';
  static const String back = 'Atrás';
  static const String forward = 'Adelante';
  static const String refresh = 'Recargar';
  static const String stop = 'Detener';
  static const String home = 'Inicio';
  static const String bookmarks = 'Favoritos';
  static const String history = 'Historial';
  static const String downloads = 'Descargas';
  static const String share = 'Compartir';

  // ─── HOME SCREEN ─────────────────────────────────────────
  static const String homeWelcome = 'Tu navegación, protegida.';
  static const String homeSubtitle =
      'Ligero. Seguro. Inteligente.';
  static const String homeSearchButton = 'Buscar';
  static const String homeTrendingTitle = 'Sitios seguros recomendados';

  // ─── SEGURIDAD — ESTADOS DE SITIO ────────────────────────
  static const String siteStatusSafe = 'Sitio seguro';
  static const String siteStatusWarning = 'Riesgo medio';
  static const String siteStatusDanger = '¡SITIO PELIGROSO!';
  static const String siteStatusUnknown = 'Sitio desconocido';

  // ─── BLOQUEADOR ───────────────────────────────────────────
  static const String adsBlockedLabel = 'elementos bloqueados';
  static const String adBlockOn = 'Protección activada';
  static const String adBlockOff = 'Protección desactivada';
  static const String trackersBlocked = 'rastreadores bloqueados';

  // ─── AVISO DE SITIO PELIGROSO ────────────────────────────
  static const String dangerTitle = '⚠️ Sitio peligroso detectado';
  static const String dangerBody =
      'DulceNav ha detectado que este sitio puede contener malware, '
      'phishing o contenido dañino. Se recomienda no continuar.';
  static const String dangerContinue = 'Continuar de todas formas (riesgo propio)';
  static const String dangerGoBack = 'Volver al sitio seguro';

  // ─── PESTAÑAS ────────────────────────────────────────────
  static const String tabHibernated = 'Pestaña en hibernación';
  static const String tabHibernatedDesc =
      'Esta pestaña fue pausada para liberar memoria. Tócala para reactivarla.';
  static const String tabLimitReached =
      'Has alcanzado el límite de pestañas abiertas (20).';

  // ─── IA (DULCEMIND MICRO) ────────────────────────────────
  static const String aiName = 'DulceMind';
  static const String aiTagline = 'Asistente inteligente · 100% local';
  static const String aiDisabledByDefault =
      'DulceMind está desactivado por defecto para no consumir recursos.';
  static const String aiActivating = 'Activando DulceMind...';
  static const String aiDeactivating = 'Liberando memoria de DulceMind...';
  static const String aiSummarize = 'Resumir esta página';
  static const String aiAnalyzeSecurity = 'Analizar seguridad';
  static const String aiTranslate = 'Traducir al español';
  static const String aiPrivacyNote =
      'DulceMind procesa todo localmente. Ningún dato sale de tu dispositivo.';

  // ─── AVISOS LEGALES OBLIGATORIOS ─────────────────────────
  static const String legalDisclaimer =
      'DulceNav es una herramienta de navegación. No aloja, almacena ni '
      'distribuye contenido. Protegemos tu conexión; el usuario es '
      'responsable de su navegación.';

  static const String privacyShort =
      'Sin telemetría · Sin rastreo · Sin datos a terceros';

  static const String legalFull =
      'DulceNav forma parte del ecosistema Dulce Universe y opera como '
      'herramienta de acceso a internet. No controla, aloja, almacena ni '
      'distribuye el contenido de los sitios web visitados. El usuario es '
      'el único responsable del uso que realice de esta aplicación y del '
      'contenido al que acceda. DulceNav no responde por daños derivados '
      'de la navegación en sitios de terceros.';

  // ─── AJUSTES ──────────────────────────────────────────────
  static const String settingsTitle = 'Ajustes de DulceNav';
  static const String settingsPerformance = 'Rendimiento';
  static const String settingsSecurity = 'Seguridad y Privacidad';
  static const String settingsAI = 'DulceMind IA';
  static const String settingsAbout = 'Acerca de';
  static const String settingsVersion = 'DulceNav v1.0.0 · Dulce Universe';

  // ─── ERRORES ──────────────────────────────────────────────
  static const String errorNoInternet = 'Sin conexión a internet';
  static const String errorPageNotFound = 'Página no encontrada';
  static const String errorGeneric = 'Error al cargar la página';
  static const String errorTryAgain = 'Reintentar';
}
