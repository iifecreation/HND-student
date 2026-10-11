// Rule-based morphological stemmer stripping common English suffixes to normalize symptom words.

/// Pure Dart morphological stemmer implementing SPEC section 8 rules.
class Stemmer {
  const Stemmer._();

  static const int minStemLength = 3;

  /// English vowels for consonant checks.
  static const Set<String> _vowels = {'a', 'e', 'i', 'o', 'u'};

  /// Checks if character [c] is an English consonant.
  static bool _isConsonant(String c) {
    if (c.length != 1) return false;
    final code = c.codeUnitAt(0);
    final isLetter = (code >= 97 && code <= 122); // a-z
    return isLetter && !_vowels.contains(c);
  }

  /// Stems a single word token according to SPEC section 8:
  /// - Strips suffixes: 'ing', 'ly', 'ed', 'es', 's' (avoiding 'ss')
  /// - If the stripped stem ends in a doubled consonant, drops one (e.g. "jamming" -> "jam")
  /// - Enforces a minimum stem length of 3 characters.
  static String stemToken(String token) {
    if (token.length <= minStemLength) return token;

    String stem = token;
    var suffixStripped = false;

    // Check suffixes in order from longest to shortest
    if (token.endsWith('ing') && (token.length - 3) >= minStemLength) {
      stem = token.substring(0, token.length - 3);
      suffixStripped = true;
    } else if (token.endsWith('ly') && (token.length - 2) >= minStemLength) {
      stem = token.substring(0, token.length - 2);
      suffixStripped = true;
    } else if (token.endsWith('ed') && (token.length - 2) >= minStemLength) {
      stem = token.substring(0, token.length - 2);
      suffixStripped = true;
    } else if (token.endsWith('es') && (token.length - 2) >= minStemLength) {
      stem = token.substring(0, token.length - 2);
      suffixStripped = true;
    } else if (token.endsWith('s') &&
        !token.endsWith('ss') &&
        (token.length - 1) >= minStemLength) {
      stem = token.substring(0, token.length - 1);
      suffixStripped = true;
    }

    // If a suffix was stripped, check for doubled consonant (e.g., "jamm" -> "jam")
    if (suffixStripped && stem.length > minStemLength) {
      final lastChar = stem[stem.length - 1];
      final secondLastChar = stem[stem.length - 2];

      if (lastChar == secondLastChar && _isConsonant(lastChar)) {
        stem = stem.substring(0, stem.length - 1);
      }
    }

    return stem;
  }

  /// Stems a list of word tokens.
  static List<String> stemTokens(List<String> tokens) {
    return tokens.map(stemToken).toList(growable: false);
  }

  /// Stems a whitespace-delimited string of tokens.
  static String stemText(String text) {
    if (text.isEmpty) return '';
    return text.split(' ').map(stemToken).join(' ');
  }
}
