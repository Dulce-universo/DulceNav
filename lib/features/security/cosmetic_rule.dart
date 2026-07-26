// ==============================================================
// DulceNav - cosmetic_rule.dart
// Modelo de dato para reglas cosméticas de adblock (CSS hiding).
// Compatibles con formato ABP: dominio.com##.selector
// ==============================================================

/// Representa una regla cosmética de bloqueo de anuncios.
/// Compatible con el formato AdBlock Plus / uBlock Origin.
///
/// Ejemplos:
///   `##.ad-banner`          → domain=null,  selector='.ad-banner'
///   `youtube.com##.ytp-ad`  → domain='youtube.com', selector='.ytp-ad'
///   `example.com#?#.ad`     → isAdvanced=true
class CosmeticRule {
  /// Dominio al que aplica. null = aplica globalmente a todos los sitios.
  final String? domain;

  /// Selector CSS a ocultar, e.g. `.ad-banner`, `#publicidad`, `div[data-ad]`.
  final String selector;

  /// true si la regla usa la sintaxis avanzada #?# (con condiciones JS).
  /// Se aplica igual que una regla normal (progressive enhancement).
  final bool isAdvanced;

  const CosmeticRule({
    required this.selector,
    this.domain,
    this.isAdvanced = false,
  });

  @override
  String toString() =>
      'CosmeticRule(domain: $domain, selector: $selector, advanced: $isAdvanced)';
}
