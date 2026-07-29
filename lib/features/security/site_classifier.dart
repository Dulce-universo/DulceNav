// ==============================================================
// DulceNav - site_classifier.dart v1.2.1
// Clasifica la URL actual: seguro / advertencia / peligroso.
// Alimenta SecurityBadge con estado reactivo via ChangeNotifier.
//
// OPTIMIZACIONES v1.2.1:
//   - Puntuacion re-calibrada (menos falsos positivos)
//   - Lista blanca ampliada con dominios comunes
//   - Clasificacion solo se notifica si el estado cambia
//   - Metodos de verificacion mas robustos
// ==============================================================

import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../shared/widgets/security_badge.dart';

class SiteClassifier extends ChangeNotifier {
  // ── Estado publico ─────────────────────────────────────────
  SiteStatus _currentStatus = SiteStatus.unknown;
  SiteStatus get currentStatus => _currentStatus;

  String _currentUrl = '';
  String get currentUrl => _currentUrl;

  // ── Lista blanca (siempre seguros) ─────────────────────────
  // Dominios que nunca se marcan como riesgo, incluso sin HTTPS.
  static const List<String> _whitelist = <String>[
    'google.com',
    'youtube.com',
    'googleapis.com',
    'gstatic.com',
    'gmail.com',
    'github.com',
    'githubusercontent.com',
    'wikipedia.org',
    'wikimedia.org',
    'dulceapps.lovable.app',
    'microsoft.com',
    'microsoftonline.com',
    'live.com',
    'office.com',
    'windows.com',
    'apple.com',
    'icloud.com',
    'mozilla.org',
    'firefox.com',
    'stackoverflow.com',
    'stackexchange.com',
    'flutter.dev',
    'dart.dev',
    'pub.dev',
    'npmjs.com',
    'cloudflare.com',
    'fastly.net',
    'amazon.com',
    'amazonaws.com',
    'netflix.com',
    'spotify.com',
    'twitter.com',
    'x.com',
    'facebook.com',
    'instagram.com',
    'linkedin.com',
    'reddit.com',
    'medium.com',
    'notion.so',
    'figma.com',
    'vercel.app',
    'netlify.app',
    'lovable.app',
  ];

  // ── Dominios maliciosos conocidos (lista negra estatica) ───
  // Fase 3 amplia esto via IA local.
  static final HashSet<String> _blacklist = HashSet<String>.from(<String>[
    'malware.testing.google.test',
    'testsafebrowsing.appspot.com',
  ]);

  // ── TLDs de alto riesgo ────────────────────────────────────
  // Frecuentemente usados en campanas de phishing y spam.
  static const List<String> _highRiskTLDs = <String>[
    '.xyz', '.top', '.click', '.gq', '.ml', '.cf', '.tk',
    '.pw', '.cam', '.icu', '.cyou', '.rest',
  ];

  // ── Palabras clave sospechosas en el PATH de la URL ────────
  // Solo se evalua el path/query, NO el dominio (evita falsos positivos).
  static const List<String> _suspiciousKeywords = <String>[
    'secure-verify',
    'account-suspended',
    'verify-identity',
    'confirm-payment',
    'signin-security',
    'update-billing',
    'apple-support-alert',
    'microsoft-security-alert',
    'free-prize-claim',
    'claim-your-reward',
    'urgent-action-required',
    'your-account-blocked',
  ];

  // ── CLASIFICAR URL ─────────────────────────────────────────
  // Devuelve el nuevo estado y notifica si cambio.

  SiteStatus classify(String url) {
    // URLs internas: desconocido (sin analisis)
    if (url.isEmpty || _isInternal(url)) {
      return _updateAndReturn(url, SiteStatus.unknown);
    }

    final Uri? parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty) {
      return _updateAndReturn(url, SiteStatus.unknown);
    }

    final String host   = parsed.host.toLowerCase();
    final String scheme = parsed.scheme.toLowerCase();

    // 1. Lista blanca
    if (_isWhitelisted(host)) {
      return _updateAndReturn(url, SiteStatus.safe);
    }

    // 2. Lista negra conocida
    if (_blacklist.contains(host)) {
      return _updateAndReturn(url, SiteStatus.danger);
    }

    // 3. Puntuacion heuristica
    final int score = _score(url, host, scheme, parsed);

    final SiteStatus status;
    if (score >= 4) {
      status = SiteStatus.danger;
    } else if (score >= 2) {
      status = SiteStatus.warning;
    } else if (scheme == 'https') {
      status = SiteStatus.safe;
    } else {
      // HTTP sin puntaje de riesgo = advertencia leve
      status = SiteStatus.warning;
    }

    return _updateAndReturn(url, status);
  }

  // ── CALCULO DE PUNTAJE DE RIESGO ──────────────────────────
  // Suma puntos por factores de riesgo.
  // Se requieren mas puntos para llegar a "danger" (reduce falsos positivos).

  int _score(String url, String host, String scheme, Uri parsed) {
    int pts = 0;

    // HTTP sin cifrado: leve (muchos sitios legales aun usan HTTP)
    if (scheme == 'http') pts += 1;

    // TLD de alto riesgo: moderado
    for (final String tld in _highRiskTLDs) {
      if (host.endsWith(tld)) { pts += 2; break; }
    }

    // Palabras clave sospechosas en path/query (no en host)
    final String pathAndQuery =
        (parsed.path + parsed.query).toLowerCase();
    for (final String kw in _suspiciousKeywords) {
      if (pathAndQuery.contains(kw)) { pts += 3; break; }
    }

    // Dominio excesivamente largo (>60 chars)
    if (host.length > 60) pts += 1;

    // Demasiados subdominios (>= 4 puntos en el host)
    // Ejemplo: a.b.c.d.evil.com -> partes = [a,b,c,d,evil,com] -> 5 puntos
    final int dots = host.split('.').length - 1;
    if (dots >= 4) pts += 2;

    // IP directa en lugar de dominio
    if (_isIPv4(host)) pts += 2;

    // Puerto no estandar y sospechoso (no 80/443/8080/8443)
    if (parsed.hasPort) {
      final int p = parsed.port;
      if (p != 80 && p != 443 && p != 8080 && p != 8443) {
        pts += 1;
      }
    }

    return pts;
  }

  // ── VERIFICACIONES ─────────────────────────────────────────

  bool _isInternal(String url) =>
      url.startsWith('about:') ||
      url.startsWith('data:') ||
      url.startsWith('javascript:') ||
      url.startsWith('file:') ||
      url == 'about:dulcenav';

  bool _isWhitelisted(String host) {
    for (final String safe in _whitelist) {
      if (host == safe || host.endsWith('.$safe')) return true;
    }
    return false;
  }

  bool _isIPv4(String host) {
    final RegExp ipv4 = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    return ipv4.hasMatch(host);
  }

  // Actualiza el estado solo si cambio, y notifica
  SiteStatus _updateAndReturn(String url, SiteStatus status) {
    if (_currentUrl != url || _currentStatus != status) {
      _currentUrl    = url;
      _currentStatus = status;
      notifyListeners();
    }
    return status;
  }

  // Resetear al cambiar de pestana
  void reset() {
    _currentUrl    = '';
    _currentStatus = SiteStatus.unknown;
    notifyListeners();
  }

  // Agregar dominio malicioso en runtime (lo usa DulceMind en Fase 3)
  void addToBlacklist(String domain) {
    _blacklist.add(domain.toLowerCase().trim());
  }
}
