// Computes Levenshtein edit distance between tokens to tolerate speech recognition and typo errors.

import 'dart:math' as math;

/// Hand-crafted Levenshtein distance algorithm for offline token comparison.
class Levenshtein {
  const Levenshtein._();

  /// Minimum token length required to permit fuzzy distance-1 matching.
  static const int minFuzzyTokenLength = 5;

  /// Computes the classic Levenshtein distance between two strings [s] and [t].
  static int distance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    var v0 = List<int>.generate(t.length + 1, (i) => i);
    var v1 = List<int>.filled(t.length + 1, 0);

    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = math.min(
          v1[j] + 1, // Insertion
          math.min(
            v0[j + 1] + 1, // Deletion
            v0[j] + cost, // Substitution
          ),
        );
      }
      for (var j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }

  /// Checks if token [actual] matches candidate [expected] per SPEC section 8:
  /// - Exact match is always accepted.
  /// - If [allowFuzzy] is true and both tokens are >= 5 characters,
  ///   allows a Levenshtein distance of at most 1.
  static bool matches(
    String actual,
    String expected, {
    bool allowFuzzy = true,
  }) {
    if (actual == expected) return true;
    if (!allowFuzzy) return false;

    // Tokens must be at least 5 characters to permit distance 1
    if (actual.length >= minFuzzyTokenLength &&
        expected.length >= minFuzzyTokenLength) {
      if ((actual.length - expected.length).abs() > 1) {
        return false;
      }
      return distance(actual, expected) <= 1;
    }

    return false;
  }
}
