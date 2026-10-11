// Extracts printer symptoms from normalized text using longest-phrase matching, fuzzy matching, and negation detection.

import 'dart:math' as math;
import '../knowledge/kb_loader.dart';
import '../knowledge/symptom.dart';
import 'levenshtein.dart';
import 'stemmer.dart';
import 'text_normalizer.dart';

/// Represents an individual symptom extracted from user text with its matched span and polarity.
class ExtractedSymptom {
  /// The matched symptom identifier (e.g. "paper_jam").
  final String symptomId;

  /// True if affirmed positively, false if negated ("no jam").
  final bool isPresent;

  /// The raw matched phrase as it appeared in the utterance.
  final String matchedText;

  /// Starting token index in the normalized utterance.
  final int startIndex;

  /// Ending token index (exclusive) in the normalized utterance.
  final int endIndex;

  const ExtractedSymptom({
    required this.symptomId,
    required this.isPresent,
    required this.matchedText,
    required this.startIndex,
    required this.endIndex,
  });

  @override
  String toString() =>
      'ExtractedSymptom($symptomId, isPresent: $isPresent, matched: "$matchedText" [$startIndex-$endIndex])';
}

/// Internal pre-stemmed synonym phrase descriptor preserving raw and stemmed tokens.
class _StemmedSynonym {
  final String symptomId;
  final List<String> rawTokens;
  final List<String> stemmedTokens;
  final int tokenCount;
  final String originalPhrase;

  const _StemmedSynonym({
    required this.symptomId,
    required this.rawTokens,
    required this.stemmedTokens,
    required this.tokenCount,
    required this.originalPhrase,
  });
}

/// Internal candidate match in an utterance.
class _MatchCandidate {
  final String symptomId;
  final int startIndex;
  final int endIndex;
  final int length;

  const _MatchCandidate({
    required this.symptomId,
    required this.startIndex,
    required this.endIndex,
    required this.length,
  });
}

/// Extracts symptoms from free text using longest-phrase matching, fuzzy matching, and negation.
class SymptomExtractor {
  final List<_StemmedSynonym> _synonymIndex;

  /// Constructs a SymptomExtractor from a list of [Symptom] definitions.
  SymptomExtractor(List<Symptom> symptoms)
      : _synonymIndex = _buildSynonymIndex(symptoms);

  /// Constructs a SymptomExtractor from a [KnowledgeBase].
  factory SymptomExtractor.fromKnowledgeBase(KnowledgeBase kb) {
    return SymptomExtractor(kb.symptomList);
  }

  /// Builds a sorted stemmed synonym index at load time.
  static List<_StemmedSynonym> _buildSynonymIndex(List<Symptom> symptoms) {
    final index = <_StemmedSynonym>[];

    for (final symptom in symptoms) {
      for (final synonym in symptom.synonyms) {
        final rawTokens = TextNormalizer.tokenize(synonym);
        if (rawTokens.isEmpty) continue;

        final stemmed = rawTokens
            .map(Stemmer.stemToken)
            .toList(growable: false);

        index.add(_StemmedSynonym(
          symptomId: symptom.id,
          rawTokens: rawTokens,
          stemmedTokens: stemmed,
          tokenCount: stemmed.length,
          originalPhrase: synonym,
        ));
      }
    }

    // Sort descending by tokenCount to prefer longest phrases first
    index.sort((a, b) => b.tokenCount.compareTo(a.tokenCount));
    return List.unmodifiable(index);
  }

  /// Recognized negator words per SPEC section 8.
  static const Set<String> _negators = {
    'no',
    'not',
    'dont',
    'doesnt',
    'isnt',
    'without',
    'never',
    'nothing',
    'cant',
    'cannot',
  };

  /// Clause boundaries that prevent negators from carrying over into subsequent clauses.
  static const Set<String> _clauseBoundaries = {
    'but',
    'however',
    'although',
    'though',
    'yet',
  };

  /// Extracts all matching symptoms from [utterance] with polarity.
  List<ExtractedSymptom> extractSymptoms(String utterance) {
    final rawTokens = TextNormalizer.tokenize(utterance);
    if (rawTokens.isEmpty) return const [];

    final stemmedTokens = rawTokens
        .map(Stemmer.stemToken)
        .toList(growable: false);
    final n = stemmedTokens.length;

    // 1. Find all candidate matches across all token positions
    final candidates = <_MatchCandidate>[];

    for (var i = 0; i < n; i++) {
      for (final synonym in _synonymIndex) {
        final k = synonym.tokenCount;
        if (i + k > n) continue;

        var matches = true;
        for (var j = 0; j < k; j++) {
          final actualStem = stemmedTokens[i + j];
          final expectedStem = synonym.stemmedTokens[j];
          final actualRaw = rawTokens[i + j];
          final expectedRaw = synonym.rawTokens[j];

          // Token matches if stemmed match, fuzzy stemmed match, or fuzzy raw match succeeds
          final tokenMatch = (actualStem == expectedStem) ||
              Levenshtein.matches(actualStem, expectedStem, allowFuzzy: true) ||
              Levenshtein.matches(actualRaw, expectedRaw, allowFuzzy: true);

          if (!tokenMatch) {
            matches = false;
            break;
          }
        }

        if (matches) {
          candidates.add(_MatchCandidate(
            symptomId: synonym.symptomId,
            startIndex: i,
            endIndex: i + k,
            length: k,
          ));
        }
      }
    }

    // 2. Sort candidates: longest phrase first, then earliest position
    candidates.sort((a, b) {
      final lenComp = b.length.compareTo(a.length);
      if (lenComp != 0) return lenComp;
      return a.startIndex.compareTo(b.startIndex);
    });

    // 3. Greedy non-overlapping match selection
    final claimedIndices = <int>{};
    final acceptedMatches = <_MatchCandidate>[];

    for (final cand in candidates) {
      var overlaps = false;
      for (var idx = cand.startIndex; idx < cand.endIndex; idx++) {
        if (claimedIndices.contains(idx)) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) continue;

      for (var idx = cand.startIndex; idx < cand.endIndex; idx++) {
        claimedIndices.add(idx);
      }
      acceptedMatches.add(cand);
    }

    // Sort accepted matches in text order
    acceptedMatches.sort((a, b) => a.startIndex.compareTo(b.startIndex));

    // 4. Evaluate negation and construct output
    final results = <ExtractedSymptom>[];

    for (final match in acceptedMatches) {
      final isNegated = _isNegatedAt(rawTokens, match.startIndex);
      final matchedText =
          rawTokens.sublist(match.startIndex, match.endIndex).join(' ');

      results.add(ExtractedSymptom(
        symptomId: match.symptomId,
        isPresent: !isNegated,
        matchedText: matchedText,
        startIndex: match.startIndex,
        endIndex: match.endIndex,
      ));
    }

    return results;
  }

  /// Determines if a match starting at [startIndex] is preceded by a negator
  /// within 3 tokens without an intervening clause boundary.
  bool _isNegatedAt(List<String> rawTokens, int startIndex) {
    final lookbackMin = math.max(0, startIndex - 3);

    for (var i = startIndex - 1; i >= lookbackMin; i--) {
      final token = rawTokens[i];

      // A clause boundary like 'but' isolates negation from following clauses
      if (_clauseBoundaries.contains(token)) {
        return false;
      }

      if (_negators.contains(token)) {
        return true;
      }
    }

    return false;
  }

  /// Convenience method returning a map of symptomId -> isPresent (true or false).
  ///
  /// If a symptom was stated positively and negatively in different clauses,
  /// positive assertion takes precedence.
  Map<String, bool> extractFacts(String utterance) {
    final extracted = extractSymptoms(utterance);
    final facts = <String, bool>{};

    for (final item in extracted) {
      // Positive assertion takes precedence
      if (facts[item.symptomId] == true) {
        continue;
      }
      facts[item.symptomId] = item.isPresent;
    }

    return facts;
  }
}
