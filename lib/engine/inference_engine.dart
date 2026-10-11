// Evaluates diagnostic rules via forward chaining to infer ranked fault candidates and certainty factors.

import 'dart:math' as math;
import '../knowledge/rule.dart';
import 'certainty.dart';
import 'working_memory.dart';

/// Captures a rule that fired during inference along with its certainty contribution.
class FiredRule {
  final Rule rule;
  final double ruleCf;
  final double evidenceCf;

  const FiredRule({
    required this.rule,
    required this.ruleCf,
    required this.evidenceCf,
  });

  @override
  String toString() =>
      'FiredRule(${rule.id} -> ${rule.then}, ruleCf: $ruleCf, evidenceCf: $evidenceCf)';
}

/// Represents a candidate fault derived by inference, its combined CF, and supporting rules.
class FaultCandidate {
  final String faultId;
  final double cf;
  final List<FiredRule> firedRules;

  const FaultCandidate({
    required this.faultId,
    required this.cf,
    required this.firedRules,
  });

  @override
  String toString() =>
      'FaultCandidate(faultId: $faultId, cf: ${cf.toStringAsFixed(2)}, rules: ${firedRules.length})';
}

/// Results returned by a single pass of the inference engine.
class InferenceResult {
  /// Ranked candidate faults sorted by certainty factor descending.
  final List<FaultCandidate> candidates;

  /// Complete list of rules that fired during this inference pass.
  final List<FiredRule> firedRules;

  /// True if a safety override rule (such as F20 for overheating) fired.
  final bool hasSafetyOverride;

  /// Identifier of the safety fault if triggered.
  final String? safetyFaultId;

  const InferenceResult({
    required this.candidates,
    required this.firedRules,
    this.hasSafetyOverride = false,
    this.safetyFaultId,
  });

  /// The highest-ranked candidate fault, or null if no rules fired.
  FaultCandidate? get topCandidate =>
      candidates.isNotEmpty ? candidates.first : null;

  /// Certainty factor of the top candidate, or 0.0.
  double get topCf => topCandidate?.cf ?? 0.0;

  /// Certainty factor of the second-ranked candidate, or 0.0.
  double get secondCf => candidates.length > 1 ? candidates[1].cf : 0.0;

  /// Difference between the top candidate CF and second candidate CF.
  double get cfMargin => topCf - secondCf;

  /// Checks if confidence criteria from SPEC section 7 are satisfied:
  /// top CF >= 0.75 AND (top CF - second CF) >= 0.15.
  bool get meetsConfidenceCriteria =>
      topCf >= 0.75 && (topCf - secondCf) >= 0.15;

  /// Evaluates whether the dialogue should conclude based on confidence,
  /// safety override, question limit (>= 6), or exhausted candidate questions.
  bool shouldConclude({
    int questionsAsked = 0,
    bool noUsefulQuestionsRemaining = false,
  }) {
    if (hasSafetyOverride) return true;
    if (meetsConfidenceCriteria) return true;
    if (questionsAsked >= 6) return true;
    if (noUsefulQuestionsRemaining) return true;
    return false;
  }
}

/// Forward chaining inference engine using MYCIN certainty factor combination.
class InferenceEngine {
  const InferenceEngine();

  /// Evaluates whether [rule] conditions are satisfied by [wm].
  ///
  /// A rule is satisfied when:
  /// 1. Every symptom in `rule.all` is TRUE.
  /// 2. At least one symptom in `rule.any` is TRUE (if `any` is non-empty).
  /// 3. No symptom in `rule.none` is TRUE.
  bool isSatisfied(Rule rule, WorkingMemory wm) {
    // 1. All required symptoms must be TRUE
    for (final symptomId in rule.all) {
      if (!wm.isTrue(symptomId)) {
        return false;
      }
    }

    // 2. If 'any' is present, at least one must be TRUE
    if (rule.any.isNotEmpty) {
      var anySatisfied = false;
      for (final symptomId in rule.any) {
        if (wm.isTrue(symptomId)) {
          anySatisfied = true;
          break;
        }
      }
      if (!anySatisfied) {
        return false;
      }
    }

    // 3. No symptom in 'none' may be TRUE
    for (final symptomId in rule.none) {
      if (wm.isTrue(symptomId)) {
        return false;
      }
    }

    return true;
  }

  /// Computes the evidence certainty factor for a satisfied rule premise.
  ///
  /// Takes the minimum certainty among all TRUE symptoms in `rule.all` and
  /// the maximum certainty among matching TRUE symptoms in `rule.any`.
  double computeEvidenceCertainty(Rule rule, WorkingMemory wm) {
    final certainties = <double>[];

    for (final symptomId in rule.all) {
      certainties.add(wm.getCertainty(symptomId));
    }

    if (rule.any.isNotEmpty) {
      var maxAny = 0.0;
      for (final symptomId in rule.any) {
        if (wm.isTrue(symptomId)) {
          maxAny = math.max(maxAny, wm.getCertainty(symptomId));
        }
      }
      if (maxAny > 0.0) {
        certainties.add(maxAny);
      }
    }

    return minEvidenceCertainty(certainties);
  }

  /// Runs forward-chaining reasoning over [rules] given current facts in [workingMemory].
  ///
  /// Faults in [excludedFaults] are skipped (e.g. if a previous fix failed).
  InferenceResult infer({
    required WorkingMemory workingMemory,
    required List<Rule> rules,
    Set<String> excludedFaults = const {},
  }) {
    final candidateCfs = <String, double>{};
    final candidateRules = <String, List<FiredRule>>{};
    final allFiredRules = <FiredRule>[];

    var safetyOverride = false;
    String? safetyFault;

    for (final rule in rules) {
      // Exclude previously rejected faults (FR10)
      if (excludedFaults.contains(rule.then)) {
        continue;
      }

      if (!isSatisfied(rule, workingMemory)) {
        continue;
      }

      final evidenceCf = computeEvidenceCertainty(rule, workingMemory);
      final ruleCf = rule.cf * evidenceCf;

      final oldCf = candidateCfs[rule.then] ?? 0.0;
      final newCf = combine(oldCf, ruleCf);
      candidateCfs[rule.then] = newCf;

      final fired = FiredRule(
        rule: rule,
        ruleCf: ruleCf,
        evidenceCf: evidenceCf,
      );
      allFiredRules.add(fired);
      candidateRules.putIfAbsent(rule.then, () => []).add(fired);

      if (rule.safety) {
        safetyOverride = true;
        safetyFault = rule.then;
      }
    }

    final candidates = candidateCfs.entries.map((entry) {
      return FaultCandidate(
        faultId: entry.key,
        cf: entry.value,
        firedRules: List.unmodifiable(candidateRules[entry.key] ?? []),
      );
    }).toList()
      ..sort((a, b) {
        if (safetyOverride) {
          if (a.faultId == safetyFault) return -1;
          if (b.faultId == safetyFault) return 1;
        }
        return b.cf.compareTo(a.cf);
      });

    return InferenceResult(
      candidates: List.unmodifiable(candidates),
      firedRules: List.unmodifiable(allFiredRules),
      hasSafetyOverride: safetyOverride,
      safetyFaultId: safetyFault,
    );
  }
}
