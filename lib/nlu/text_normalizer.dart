// Normalizes user speech and text input by converting to lowercase, removing punctuation, and collapsing whitespace.

/// Pure Dart utility for text normalization and tokenization.
class TextNormalizer {
  const TextNormalizer._();

  /// Regular expression matching straight and curly apostrophes to strip them without adding spaces.
  static final RegExp _apostrophesRegex = RegExp(r"['’‘`]");

  /// Regular expression matching non-alphanumeric characters (to replace with spaces).
  static final RegExp _nonAlphaNumericRegex = RegExp(r'[^a-z0-9\s]');

  /// Regular expression matching multiple consecutive spaces.
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');

  /// Normalizes [input] per SPEC section 8:
  /// 1. Lowercase
  /// 2. Remove apostrophes ("won't" -> "wont", "it's" -> "its")
  /// 3. Replace all other punctuation with spaces
  /// 4. Collapse consecutive whitespace characters into a single space and trim.
  static String normalize(String input) {
    if (input.isEmpty) return '';

    // 1. Lowercase
    var text = input.toLowerCase();

    // 2. Remove apostrophes
    text = text.replaceAll(_apostrophesRegex, '');

    // 3. Replace other punctuation with spaces
    text = text.replaceAll(_nonAlphaNumericRegex, ' ');

    // 4. Collapse spaces and trim
    text = text.replaceAll(_multiSpaceRegex, ' ').trim();

    return text;
  }

  /// Normalizes and splits [input] into a list of word tokens.
  static List<String> tokenize(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return const [];
    return normalized.split(' ');
  }
}
