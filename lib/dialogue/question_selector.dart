// Selects the most informative next follow-up question based on rule coverage among top candidate faults.

import '../engine/inference_engine.dart';
import '../engine/working_memory.dart';
import '../knowledge/kb_loader.dart';
import '../knowledge/symptom.dart';

/// Helper container tracking question scoring metrics for candidate ranking.
class _SymptomScore {
  final String symptomId;
  int ruleCount = 0;
  double sumCf = 0.0;

  _SymptomScore(this.symptomId);
}

/// Information-maximizing question selector implementing SPEC section 9 rules.
class QuestionSelector {
  final KnowledgeBase kb;

  const QuestionSelector(this.kb);

  /// Selects the most informative next symptom to question.
  ///
  /// Heuristic criteria per SPEC section 9:
  /// 1. Prioritizes printer type (laser vs inkjet) early if any candidate rule needs it.
  /// 2. Considers symptoms still UNKNOWN that appear in rules of the top 5 candidate faults
  ///    (including both active concluded faults and partially-active candidate faults).
  /// 3. Chooses the symptom appearing in the most such rules.
  /// 4. Breaks ties by highest sum of rule certainty factors (CF).
  Symptom? selectNextQuestion({
    required WorkingMemory workingMemory,
    required List<FaultCandidate> candidates,
    Set<String> excludedFaults = const {},
  }) {
    // 1. Gather candidate faults:
    // A) Faults that have already fired rules (sorted by CF desc)
    final firedFaultIds = candidates
        .map((c) => c.faultId)
        .where((f) => !excludedFaults.contains(f))
        .toList();

    // B) Partially active faults: rules where some symptoms are TRUE and none are FALSE
    final partialScores = <String, double>{};
    for (final rule in kb.rules) {
      if (excludedFaults.contains(rule.then)) continue;

      var hasFalse = false;
      var trueCount = 0;
      var unknownCount = 0;

      for (final symptomId in rule.all) {
        if (workingMemory.isFalse(symptomId)) {
          hasFalse = true;
          break;
        } else if (workingMemory.isTrue(symptomId)) {
          trueCount++;
        } else {
          unknownCount++;
        }
      }
      if (hasFalse) continue;

      for (final symptomId in rule.none) {
        if (workingMemory.isTrue(symptomId)) {
          hasFalse = true;
          break;
        }
      }
      if (hasFalse) continue;

      if (trueCount > 0 && unknownCount > 0) {
        final score = rule.cf * (trueCount / (trueCount + unknownCount));
        partialScores[rule.then] = (partialScores[rule.then] ?? 0.0) + score;
      }
    }

    final rankedPartialFaultIds = partialScores.keys.toList()
      ..sort((a, b) => partialScores[b]!.compareTo(partialScores[a]!));

    // Combine into top 5 active candidate fault IDs
    final candidateFaultIds = <String>{};
    for (final f in firedFaultIds) {
      candidateFaultIds.add(f);
      if (candidateFaultIds.length >= 5) break;
    }
    for (final f in rankedPartialFaultIds) {
      if (candidateFaultIds.length >= 5) break;
      candidateFaultIds.add(f);
    }

    // 2. Find rules concluding these candidate faults
    final candidateRules = kb.rules.where((r) {
      if (excludedFaults.contains(r.then)) return false;
      if (candidateFaultIds.isNotEmpty && !candidateFaultIds.contains(r.then)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    // 3. Early printer type check: if any candidate rule needs laser or inkjet, ask early
    final needsPrinterType = candidateRules.any((r) =>
        r.all.contains('type_laser') ||
        r.all.contains('type_inkjet') ||
        r.any.contains('type_laser') ||
        r.any.contains('type_inkjet'));

    if (needsPrinterType) {
      if (workingMemory.isUnknown('type_laser') &&
          workingMemory.isUnknown('type_inkjet')) {
        final laserSymptom = kb.getSymptom('type_laser');
        if (laserSymptom != null) {
          return laserSymptom;
        }
      }
    }

    // 4. Score unknown symptoms across relevant candidate rules
    final symptomScores = <String, _SymptomScore>{};

    for (final rule in candidateRules) {
      final symptomsInRule = <String>{...rule.all, ...rule.any, ...rule.none};
      for (final symptomId in symptomsInRule) {
        if (!workingMemory.isUnknown(symptomId)) continue;

        final score = symptomScores.putIfAbsent(
          symptomId,
          () => _SymptomScore(symptomId),
        );
        score.ruleCount++;
        score.sumCf += rule.cf;
      }
    }

    // Fallback: If candidate rules yield no unknown symptoms, examine all active rules
    if (symptomScores.isEmpty) {
      for (final rule in kb.rules) {
        if (excludedFaults.contains(rule.then)) continue;
        final symptomsInRule = <String>{...rule.all, ...rule.any, ...rule.none};
        for (final symptomId in symptomsInRule) {
          if (!workingMemory.isUnknown(symptomId)) continue;

          final score = symptomScores.putIfAbsent(
            symptomId,
            () => _SymptomScore(symptomId),
          );
          score.ruleCount++;
          score.sumCf += rule.cf;
        }
      }
    }

    if (symptomScores.isEmpty) return null;

    // 5. Rank symptoms by ruleCount desc, then sumCf desc, then ID asc
    final ranked = symptomScores.values.toList()
      ..sort((a, b) {
        final countComparison = b.ruleCount.compareTo(a.ruleCount);
        if (countComparison != 0) return countComparison;

        final cfComparison = b.sumCf.compareTo(a.sumCf);
        if (cfComparison != 0) return cfComparison;

        return a.symptomId.compareTo(b.symptomId);
      });

    return kb.getSymptom(ranked.first.symptomId);
  }
}
