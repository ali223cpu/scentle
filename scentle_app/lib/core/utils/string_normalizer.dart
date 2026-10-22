/// String normalization utilities for diacritics, search indexing, and note formatting.
class StringNormalizer {
  const StringNormalizer._();

  static const Map<String, String> _diacritics = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae',
  };

  static final RegExp _apostrophesRegex = RegExp(r"['’`]");
  static final RegExp _punctuationRegex = RegExp(r"[-./&+,:()\[\]_]");
  static final RegExp _multiSpaceRegex = RegExp(r"\s+");

  /// Converts input to lower-case ASCII, strips diacritics and apostrophes,
  /// replaces punctuation with spaces, and collapses whitespace.
  /// Example:
  ///   "François Demachy" -> "francois demachy"
  ///   "L'Eau d'Issey" -> "leau dissey"
  ///   "Bleu de Chanel - Eau de Parfum" -> "bleu de chanel eau de parfum"
  static String normalizeForSearch(String input) {
    if (input.isEmpty) return '';

    // Convert to lowercase
    final lower = input.toLowerCase();

    // Diacritic replacement
    final buffer = StringBuffer();
    for (int i = 0; i < lower.length; i++) {
      final char = lower[i];
      buffer.write(_diacritics[char] ?? char);
    }
    String s = buffer.toString();

    // Strip apostrophes so "L'Eau" -> "leau"
    s = s.replaceAll(_apostrophesRegex, '');

    // Replace punctuation with space
    s = s.replaceAll(_punctuationRegex, ' ');

    // Collapse multiple spaces and trim
    return s.replaceAll(_multiSpaceRegex, ' ').trim();
  }

  /// Normalizes note string for exact set intersection comparisons.
  /// Example: "Elemi" -> "elemi", " Calabrian Bergamot " -> "calabrian bergamot".
  static String normalizeNoteKey(String note) {
    return note.trim().toLowerCase();
  }

  /// Converts raw note strings into clean Title Case for UI chip rendering.
  /// Example: "elemi" -> "Elemi", "calabrian bergamot" -> "Calabrian Bergamot".
  static String formatNoteDisplay(String note) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return '';

    final words = trimmed.split(RegExp(r'\s+'));
    final formattedWords = words.map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    });

    return formattedWords.join(' ');
  }
}
