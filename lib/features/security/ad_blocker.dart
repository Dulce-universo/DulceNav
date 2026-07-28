// ==============================================================
// DulceNav - ad_blocker.dart v1.2.1
// Motor principal de bloqueo de anuncios y rastreadores.
//
// ESTRATEGIA DE BLOQUEO (importante entender):
// ─────────────────────────────────────────────────────────────
// webview_windows usa Edge WebView2, que NO expone un
// NavigationDelegate para sub-recursos (solo para navegacion
// principal). Esto significa que NO podemos interceptar
// solicitudes XHR/fetch/img/script desde Dart de la misma
// forma que webview_flutter en Android.
//
// SOLUCION: Inyeccion de JavaScript en cada documento nuevo.
// El script sobreescribe window.XMLHttpRequest y window.fetch
// con versiones que verifican el dominio destino contra una
// lista de dominios bloqueados (Set JS, busqueda O(1)).
// Esto bloquea solicitudes de recursos antes de que salgan,
// sin afectar el codigo interno de la pagina.
//
// LIMITACION CONOCIDA: La navegacion principal (cambio de URL)
// no pasa por el script JS. Para esa, se usa shouldBlock() en
// browser_screen.dart antes de llamar a loadUrl().
//
// OPTIMIZACIONES v1.2.1:
//   - Script JS mas compacto (menos overhead de parseo)
//   - Limite de dominios en el script: 3000 (balance velocidad/cobertura)
//   - shouldBlock() verifica URL principal antes de cargar
//   - generateBlockScript() omite script si bloqueador esta off
// ==============================================================

import 'package:flutter/foundation.dart';
import 'blocklist_manager.dart';
import 'site_classifier.dart';
import '../../shared/widgets/security_badge.dart';

class AdBlocker extends ChangeNotifier {
  // ── Dependencias ───────────────────────────────────────────
  final BlocklistManager _blm;
  final SiteClassifier   _sc;

  AdBlocker({
    required BlocklistManager blocklistManager,
    required SiteClassifier   siteClassifier,
  })  : _blm = blocklistManager,
        _sc  = siteClassifier;

  // ── Estado publico ─────────────────────────────────────────
  bool _isEnabled               = true;
  bool get isEnabled            => _isEnabled;

  bool _trackingEnabled         = true;
  bool get trackingProtectionEnabled => _trackingEnabled;

  bool _antiPhishingEnabled     = true;
  bool get antiPhishingEnabled  => _antiPhishingEnabled;

  int  _totalBlocked            = 0;
  int  get totalBlocked         => _totalBlocked;

  // ── Esquemas internos que NUNCA se bloquean ────────────────
  static const List<String> _safeSchemes = <String>[
    'about:', 'data:', 'javascript:', 'file:',
    'chrome-extension:', 'ms-browser-extension:',
  ];

  // ── BLOQUEO DE URL PRINCIPAL ───────────────────────────────
  // Llamado por browser_screen antes de cargar una nueva URL.
  // Solo evalua la URL de navegacion, no sub-recursos.
  // Devuelve true si debe bloquearse.

  bool shouldBlock(String url) {
    if (!_isEnabled) return false;
    if (_isInternal(url)) return false;

    final String domain = _domain(url);
    if (domain.isEmpty) return false;

    if (_blm.blockedDomains.contains(domain) ||
        _matchesPattern(domain)) {
      _totalBlocked++;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── CLASIFICACION DE SEGURIDAD ─────────────────────────────
  // Llama al SiteClassifier y devuelve el estado del sitio.

  SiteStatus classifyUrl(String url) {
    if (!_antiPhishingEnabled) return SiteStatus.unknown;
    return _sc.classify(url);
  }

  // ── GENERAR SCRIPT DE BLOQUEO JS ──────────────────────────
  // Este script se inyecta en cada nuevo documento cargado en
  // el WebView mediante addScriptToExecuteOnDocumentCreated().
  //
  // Funcionamiento interno:
  //   1. Crea un Set JS con los dominios bloqueados (top 3000)
  //   2. Define isDomainBlocked(url) que verifica host y padres
  //   3. Sobreescribe XMLHttpRequest.open() para abortar si bloqueado
  //   4. Sobreescribe window.fetch() para rechazar si bloqueado
  //
  // Tipos de solicitudes bloqueadas:
  //   - Peticiones AJAX (XMLHttpRequest)
  //   - Peticiones fetch() (modernas SPA)
  //   - NO bloquea: <img>, <script>, <iframe> tags (limitacion JS)
  //     Para esos se necesitaria Service Worker, no disponible aqui.
  //
  // Rendimiento: Set() en JS tiene lookup O(1). El overhead por
  //   solicitud es < 0.1ms en benchmarks tipicos.

  String generateBlockScript() {
    // Si el bloqueador esta desactivado, no inyectar nada
    if (!_isEnabled) return '';

    // Si las listas aun no se cargaron, no inyectar
    if (_blm.totalRules == 0) return '';

    // Tomar los dominios mas utiles (patrones cubren subdominios)
    // Limite: 3000 para equilibrar tamano del script vs cobertura
    final List<String> topDomains = _blm.blockedPatterns
        .take(3000)
        .toList();

    // Serializar como array JS de strings
    final StringBuffer sb = StringBuffer();
    sb.write('[');
    for (int i = 0; i < topDomains.length; i++) {
      sb.write('"');
      sb.write(topDomains[i]);
      sb.write('"');
      if (i < topDomains.length - 1) sb.write(',');
    }
    sb.write(']');
    final String domainsArray = sb.toString();

    // Script IIFE: Immediately Invoked Function Expression
    // El scope aislado evita contaminar el espacio global de la pagina.
    return '''
(function(){
"use strict";
var BL=new Set($domainsArray);
function chk(u){
  try{
    var h=new URL(u).hostname.toLowerCase();
    if(BL.has(h))return true;
    var p=h.split(".");
    for(var i=1;i<p.length-1;i++){
      if(BL.has(p.slice(i).join(".")))return true;
    }
  }catch(e){}
  return false;
}
var ox=XMLHttpRequest.prototype.open;
XMLHttpRequest.prototype.open=function(m,u){
  if(chk(u)){this._dulce_blocked=true;return;}
  return ox.apply(this,arguments);
};
var os=XMLHttpRequest.prototype.send;
XMLHttpRequest.prototype.send=function(){
  if(this._dulce_blocked){this.abort();return;}
  return os.apply(this,arguments);
};
var of=window.fetch;
window.fetch=function(i,o){
  var u=(typeof i==="string")?i:(i&&i.url)||"";
  if(chk(u))return Promise.reject(new TypeError("DulceNav:blocked"));
  return of.apply(this,arguments);
};
})();
''';
  }

  // ── CONTROLES PUBLICOS ─────────────────────────────────────

  void toggle() {
    _isEnabled = !_isEnabled;
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (_isEnabled != value) {
      _isEnabled = value;
      notifyListeners();
    }
  }

  void setTrackingProtection(bool value) {
    if (_trackingEnabled != value) {
      _trackingEnabled = value;
      notifyListeners();
    }
  }

  void setAntiPhishing(bool value) {
    if (_antiPhishingEnabled != value) {
      _antiPhishingEnabled = value;
      notifyListeners();
    }
  }

  // Reiniciar contador al cambiar de pestana
  void resetCounter() {
    if (_totalBlocked != 0) {
      _totalBlocked = 0;
      notifyListeners();
    }
  }

  // ── UTILIDADES INTERNAS ────────────────────────────────────

  bool _isInternal(String url) {
    for (final String scheme in _safeSchemes) {
      if (url.startsWith(scheme)) return true;
    }
    return false;
  }

  String _domain(String url) {
    try {
      return Uri.tryParse(url)?.host.toLowerCase() ?? '';
    } catch (_) {
      return '';
    }
  }

  // Verifica si el dominio coincide con algun patron bloqueado.
  // Soporta subdominios: ads.example.com bloqueado si example.com esta listado.
  bool _matchesPattern(String domain) {
    if (_blm.blockedPatterns.contains(domain)) return true;

    final List<String> parts = domain.split('.');
    // Verificar cada dominio padre
    for (int i = 1; i < parts.length - 1; i++) {
      final String parent = parts.sublist(i).join('.');
      if (_blm.blockedPatterns.contains(parent) ||
          _blm.blockedDomains.contains(parent)) {
        return true;
      }
    }
    return false;
  }
}
