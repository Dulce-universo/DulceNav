// ============================================================
// DulceNav — url_utils.dart
// Validación, normalización y parsing de URLs.
// Maneja: URLs directas, búsquedas, IPs, localhost.
// ============================================================

import '../services/storage_service.dart';

class UrlUtils {
  UrlUtils._();

  // ── Procesar input del usuario ──────────────────────────
  /// Convierte el texto de la barra de URL en una URL válida.
  /// - Si parece una URL → la normaliza
  /// - Si parece una búsqueda → la convierte en búsqueda
  static String processInput(String input, {String? searchEngine}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'about:dulcenav';

    // Paginas internas (incluye alias de WebView2)
    if (trimmed.startsWith('about:')) return trimmed;
    if (trimmed.startsWith('edge://dulcenav')) return 'about:dulcenav';
    if (trimmed.startsWith('edge://')) return 'about:dulcenav';

    // Ya tiene esquema completo
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // IP o localhost directos (ej: 192.168.1.1, localhost:8080)
    if (_looksLikeHostOrIp(trimmed)) {
      return 'https://$trimmed';
    }

    // Parece dominio con TLD (ej: google.com, dulceapps.lovable.app)
    if (_looksLikeDomain(trimmed)) {
      return 'https://$trimmed';
    }

    // De lo contrario: búsqueda
    final engine = searchEngine ?? StorageService.instance.searchEngine;
    return '$engine${Uri.encodeComponent(trimmed)}';
  }

  // ── Validar URL ─────────────────────────────────────────
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'about');
    } catch (_) {
      return false;
    }
  }

  // ── Extraer dominio ────────────────────────────────────
  static String getDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  // ── Mostrar URL abreviada en barra ─────────────────────
  /// Quita 'https://www.' para mostrar limpio en la barra
  static String displayUrl(String url) {
    if (url == 'about:dulcenav') return '';
    return url
        .replaceFirst('https://', '')
        .replaceFirst('http://', '')
        .replaceFirst('www.', '');
  }

  // -- Es pagina de inicio (incluye alias de WebView2) --
  static bool isHomePage(String url) =>
      url == 'about:dulcenav' ||
      url == 'about:blank' ||
      url.isEmpty ||
      url.startsWith('edge://dulcenav') ||
      url.startsWith('edge://new-tab');

  // ── Privados ────────────────────────────────────────────
  static bool _looksLikeDomain(String text) {
    // Tiene punto y no tiene espacios → probablemente dominio
    return text.contains('.') &&
        !text.contains(' ') &&
        RegExp(r"^[a-zA-Z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+$").hasMatch(text);
  }

  static bool _looksLikeHostOrIp(String text) {
    // IPv4
    if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$')
        .hasMatch(text)) return true;
    // localhost
    if (text.startsWith('localhost')) return true;
    return false;
  }

  // ── Comparar orígenes ────────────────────────────────────
  /// True si dos URLs son del mismo dominio
  static bool sameOrigin(String url1, String url2) {
    return getDomain(url1) == getDomain(url2);
  }
}
