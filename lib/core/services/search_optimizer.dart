// ==============================================================
// DulceNav - search_optimizer.dart
// Utility class to optimize text selections for search engines.
// ==============================================================

class SearchOptimizer {
  /// Cleans the input text by collapsing spaces, newlines, tabs, and
  /// removing starting/ending symbols and noise characters.
  static String optimize(String text) {
    if (text.isEmpty) return '';

    // Collapse multiple spaces, newlines, and tabs
    String cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Strip starting/ending noise symbols (like dashes, bullets, quotes, or punctuation)
    // E.g., "  - Hotel del Sol - Manizales  " -> "Hotel del Sol - Manizales"
    // E.g., "  * Hello World!  " -> "Hello World!"
    cleaned = cleaned.replaceAll(RegExp(r'^[-_+*•\x22\x27\x60#\s]+|[-_+*•\x22\x27\x60#\s]+$'), '');

    return cleaned.trim();
  }

  /// Builds a search URL based on the query and search engine template.
  static String buildSearchUrl(String query, String engineTemplate) {
    final cleanQuery = optimize(query);
    final encodedQuery = Uri.encodeComponent(cleanQuery);
    return '$engineTemplate$encodedQuery';
  }
}
