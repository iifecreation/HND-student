// Provides why-asked and how-concluded explanations for diagnostic reasoning transparency.

import '../knowledge/kb_loader.dart';
import 'inference_engine.dart';

/// Itemized contribution of a single fired rule toward concluding a fault.
class RuleContribution {
  final String ruleId;
  final String why;
  final double contribution;
  final double evidenceCertainty;

  const RuleContribution({
    required this.ruleId,
    required this.why,
    required this.contribution,
    required this.evidenceCertainty,
  });

  @override
  String toString() =>
      'RuleContribution(rule: $ruleId, contribution: ${contribution.toStringAsFixed(2)}, why: "$why")';
}

/// Structured explanation of how a specific fault was concluded.
class FaultExplanation {
  final String faultId;
  final String? faultName;
  final double totalCf;
  final List<RuleContribution> rules;

  const FaultExplanation({
    required this.faultId,
    this.faultName,
    required this.totalCf,
    required this.rules,
  });

  /// Formats the explanation into readable lines for UI display and viva defense.
  List<String> toDisplayLines() {
    return rules
        .map((r) =>
            '${r.ruleId} (+${(r.contribution * 100).toStringAsFixed(0)}%): ${r.why}')
        .toList(growable: false);
  }
}

/// Provides transparency into the inference process via "how" and "why" inquiries.
class ExplanationFacility {
  final KnowledgeBase kb;

  const ExplanationFacility(this.kb);

  /// Explains HOW [faultId] was concluded: returns all fired rules, their human why text,
  /// and their certainty factor contributions.
  FaultExplanation how(String faultId, InferenceResult inferenceResult) {
    final candidate = inferenceResult.candidates.firstWhere(
      (c) => c.faultId == faultId,
      orElse: () =>
          FaultCandidate(faultId: faultId, cf: 0.0, firedRules: const []),
    );

    final contributions = candidate.firedRules.map((fired) {
      return RuleContribution(
        ruleId: fired.rule.id,
        why: fired.rule.why,
        contribution: fired.ruleCf,
        evidenceCertainty: fired.evidenceCf,
      );
    }).toList(growable: false);

    final fault = kb.getFault(faultId);

    return FaultExplanation(
      faultId: faultId,
      faultName: fault?.name,
      totalCf: candidate.cf,
      rules: contributions,
    );
  }

  /// Explains WHY [symptomId] is being asked: returns candidate fault IDs that this
  /// question helps confirm or rule out.
  List<String> why(
    String symptomId, {
    List<FaultCandidate> candidates = const [],
  }) {
    final candidateFaultIds =
        candidates.map((c) => c.faultId).toSet();
    final matchedFaultIds = <String>{};

    for (final rule in kb.rules) {
      if (candidateFaultIds.isNotEmpty &&
          !candidateFaultIds.contains(rule.then)) {
        continue;
      }

      final mentionsSymptom = rule.all.contains(symptomId) ||
          rule.any.contains(symptomId) ||
          rule.none.contains(symptomId);

      if (mentionsSymptom) {
        matchedFaultIds.add(rule.then);
      }
    }

    // Preserve the ranking order of the candidate faults if provided
    if (candidateFaultIds.isNotEmpty) {
      return candidates
          .where((c) => matchedFaultIds.contains(c.faultId))
          .map((c) => c.faultId)
          .toList(growable: false);
    }

    return matchedFaultIds.toList(growable: false);
  }

  /// Builds a human-friendly spoken explanation of why a question was asked.
  String whySpoken(
    String symptomId, {
    List<FaultCandidate> candidates = const [],
  }) {
    final faultIds = why(symptomId, candidates: candidates);
    if (faultIds.isEmpty) {
      return 'This helps narrow down possible printer issues.';
    }

    final faultNames = faultIds
        .map((id) => kb.getFault(id)?.name ?? id)
        .take(2)
        .toList();

    if (faultNames.length == 1) {
      return 'This helps check for ${faultNames.first}.';
    } else {
      return 'This helps distinguish between ${faultNames[0]} and ${faultNames[1]}.';
    }
  }
}
