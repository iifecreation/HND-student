// Tracks observed symptom states (TRUE, FALSE, UNKNOWN), evidence certainties, and mutual exclusions.

import '../knowledge/kb_loader.dart';

/// Tri-state logical value representing observation certainty in working memory.
enum FactValue {
  isTrue,
  isFalse,
  unknown;

  bool get isTrueVal => this == FactValue.isTrue;
  bool get isFalseVal => this == FactValue.isFalse;
  bool get isUnknownVal => this == FactValue.unknown;
}

/// Container storing the state of a symptom observation along with its certainty weight.
class SymptomEvidence {
  /// The logical observation state (TRUE, FALSE, or UNKNOWN).
  final FactValue value;

  /// Certainty level: 1.0 for definitive answer, 0.5 for unsure, 0.0 for unknown.
  final double certainty;

  const SymptomEvidence({
    required this.value,
    this.certainty = 1.0,
  });

  /// Default unasserted state.
  static const SymptomEvidence unknown = SymptomEvidence(
    value: FactValue.unknown,
    certainty: 0.0,
  );

  @override
  String toString() => 'SymptomEvidence(value: $value, certainty: $certainty)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymptomEvidence &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          certainty == other.certainty;

  @override
  int get hashCode => Object.hash(value, certainty);
}

/// Stores diagnostic facts asserted during user dialogue and handles mutual symptom exclusions.
class WorkingMemory {
  final Map<String, SymptomEvidence> _facts;
  final Map<String, List<String>> _excludes;

  WorkingMemory({
    Map<String, List<String>>? excludes,
    Map<String, SymptomEvidence>? initialFacts,
  })  : _excludes = excludes ?? const {},
        _facts = initialFacts != null ? Map.of(initialFacts) : {};

  /// Constructs working memory initialized with mutual exclusion maps from a [KnowledgeBase].
  factory WorkingMemory.fromKnowledgeBase(KnowledgeBase kb) {
    final excludesMap = <String, List<String>>{};
    for (final symptom in kb.symptomList) {
      if (symptom.excludes.isNotEmpty) {
        excludesMap[symptom.id] = List.unmodifiable(symptom.excludes);
      }
    }
    return WorkingMemory(excludes: excludesMap);
  }

  /// Asserts an observation for [symptomId].
  ///
  /// If asserted as [FactValue.isTrue], any mutually exclusive symptoms defined in
  /// the excludes map are automatically asserted as [FactValue.isFalse] with certainty 1.0.
  void setFact(String symptomId, FactValue value, {double certainty = 1.0}) {
    final clampedCf = certainty.clamp(0.0, 1.0);
    _facts[symptomId] = SymptomEvidence(
      value: value,
      certainty: value == FactValue.unknown ? 0.0 : clampedCf,
    );

    // Enforce mutual exclusions when asserted TRUE
    if (value == FactValue.isTrue) {
      final excludedList = _excludes[symptomId];
      if (excludedList != null) {
        for (final excludedId in excludedList) {
          _facts[excludedId] = const SymptomEvidence(
            value: FactValue.isFalse,
            certainty: 1.0,
          );
        }
      }
    }
  }

  /// Asserts a symptom as TRUE with the given certainty (default 1.0).
  void setTrue(String symptomId, {double certainty = 1.0}) {
    setFact(symptomId, FactValue.isTrue, certainty: certainty);
  }

  /// Asserts a symptom as FALSE with certainty 1.0.
  void setFalse(String symptomId, {double certainty = 1.0}) {
    setFact(symptomId, FactValue.isFalse, certainty: certainty);
  }

  /// Asserts a symptom as "not sure" (stored as TRUE with 0.5 certainty).
  void setUnsure(String symptomId) {
    setFact(symptomId, FactValue.isTrue, certainty: 0.5);
  }

  /// Resets a symptom to UNKNOWN.
  void setUnknown(String symptomId) {
    setFact(symptomId, FactValue.unknown, certainty: 0.0);
  }

  /// Returns the observation status of [symptomId], defaulting to UNKNOWN.
  FactValue getValue(String symptomId) {
    return _facts[symptomId]?.value ?? FactValue.unknown;
  }

  /// Returns the certainty of [symptomId], defaulting to 0.0 if not asserted.
  double getCertainty(String symptomId) {
    return _facts[symptomId]?.certainty ?? 0.0;
  }

  /// Returns true if [symptomId] has been asserted as TRUE.
  bool isTrue(String symptomId) => getValue(symptomId) == FactValue.isTrue;

  /// Returns true if [symptomId] has been asserted as FALSE.
  bool isFalse(String symptomId) => getValue(symptomId) == FactValue.isFalse;

  /// Returns true if [symptomId] is UNKNOWN.
  bool isUnknown(String symptomId) => getValue(symptomId) == FactValue.unknown;

  /// Returns all symptom IDs currently known (TRUE or FALSE).
  Set<String> get knownSymptomIds => _facts.entries
      .where((e) => e.value.value != FactValue.unknown)
      .map((e) => e.key)
      .toSet();

  /// Returns an unmodifiable snapshot of all current facts.
  Map<String, SymptomEvidence> get factsSnapshot =>
      Map.unmodifiable(_facts);

  /// Creates a deep copy of the current working memory state for hypothetical branch testing.
  WorkingMemory clone() {
    return WorkingMemory(
      excludes: _excludes,
      initialFacts: Map.of(_facts),
    );
  }

  /// Clears all asserted facts.
  void clear() {
    _facts.clear();
  }
}
