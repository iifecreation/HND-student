// Unit tests for the inference engine layer: certainty combination,
// working memory, forward chaining, safety override, explanations, and all 20 evaluation scenarios.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_doc/engine/certainty.dart';
import 'package:printer_doc/engine/explanation.dart';
import 'package:printer_doc/engine/inference_engine.dart';
import 'package:printer_doc/engine/working_memory.dart';
import 'package:printer_doc/knowledge/kb_loader.dart';
import 'package:printer_doc/knowledge/rule.dart';

void main() {
  group('Certainty Factor Combination (certainty.dart)', () {
    test('standard MYCIN combination formula', () {
      // 0.8 + 0.6 * (1 - 0.8) = 0.8 + 0.12 = 0.92
      final combined = combine(0.80, 0.60);
      expect(combined, closeTo(0.92, 0.0001));
    });

    test('commutativity: combine(a, b) == combine(b, a)', () {
      expect(combine(0.70, 0.40), closeTo(combine(0.40, 0.70), 0.0001));
      expect(combine(0.95, 0.30), closeTo(combine(0.30, 0.95), 0.0001));
    });

    test('boundary values and clamping', () {
      expect(combine(0.0, 0.5), equals(0.5));
      expect(combine(1.0, 0.5), equals(1.0));
      expect(combine(0.0, 0.0), equals(0.0));
      expect(combine(1.0, 1.0), equals(1.0));
    });

    test('combineAll reduces a list correctly', () {
      // combine(0.5, 0.5) = 0.75
      expect(combineAll([0.5, 0.5]), closeTo(0.75, 0.0001));
      // combine(0.75, 0.5) = 0.875
      expect(combineAll([0.5, 0.5, 0.5]), closeTo(0.875, 0.0001));
    });

    test('minEvidenceCertainty computes fuzzy AND', () {
      expect(minEvidenceCertainty([1.0, 0.5]), equals(0.5));
      expect(minEvidenceCertainty([0.8, 0.9, 0.6]), closeTo(0.6, 0.0001));
      expect(minEvidenceCertainty([]), equals(1.0));
    });
  });

  group('Working Memory (working_memory.dart)', () {
    test('default status is unknown', () {
      final wm = WorkingMemory();
      expect(wm.getValue('paper_jam'), equals(FactValue.unknown));
      expect(wm.isUnknown('paper_jam'), isTrue);
      expect(wm.isTrue('paper_jam'), isFalse);
      expect(wm.isFalse('paper_jam'), isFalse);
    });

    test('setTrue and setFalse record facts with certainty', () {
      final wm = WorkingMemory();
      wm.setTrue('paper_jam', certainty: 1.0);
      wm.setFalse('error_light', certainty: 1.0);

      expect(wm.isTrue('paper_jam'), isTrue);
      expect(wm.getCertainty('paper_jam'), equals(1.0));
      expect(wm.isFalse('error_light'), isTrue);
      expect(wm.getCertainty('error_light'), equals(1.0));
    });

    test('setUnsure records fact as TRUE with 0.5 certainty', () {
      final wm = WorkingMemory();
      wm.setUnsure('paper_jam');

      expect(wm.isTrue('paper_jam'), isTrue);
      expect(wm.getCertainty('paper_jam'), equals(0.5));
    });

    test('mutual exclusion triggers when symptom is set to TRUE', () {
      final wm = WorkingMemory(excludes: {
        'type_laser': ['type_inkjet'],
        'type_inkjet': ['type_laser'],
      });

      wm.setTrue('type_laser');

      expect(wm.isTrue('type_laser'), isTrue);
      expect(wm.isFalse('type_inkjet'), isTrue);
      expect(wm.getCertainty('type_inkjet'), equals(1.0));
    });

    test('clone creates an independent deep copy', () {
      final wm = WorkingMemory();
      wm.setTrue('s1');

      final copy = wm.clone();
      copy.setTrue('s2');

      expect(wm.isTrue('s2'), isFalse);
      expect(copy.isTrue('s1'), isTrue);
      expect(copy.isTrue('s2'), isTrue);
    });
  });

  group('Inference Engine (inference_engine.dart)', () {
    const engine = InferenceEngine();

    test('single rule satisfaction and CF propagation', () {
      final wm = WorkingMemory();
      wm.setTrue('s1', certainty: 1.0);
      wm.setTrue('s2', certainty: 0.8);

      final rules = [
        const Rule(
          id: 'R01',
          all: ['s1', 's2'],
          then: 'F01',
          cf: 0.90,
          why: 'Test rule',
        ),
      ];

      final result = engine.infer(workingMemory: wm, rules: rules);

      expect(result.candidates.length, equals(1));
      expect(result.topCandidate?.faultId, equals('F01'));
      // evidenceCf = min(1.0, 0.8) = 0.8; ruleCf = 0.9 * 0.8 = 0.72
      expect(result.topCf, closeTo(0.72, 0.0001));
    });

    test('multiple rules combining for same fault', () {
      final wm = WorkingMemory();
      wm.setTrue('s1');
      wm.setTrue('s2');

      final rules = [
        const Rule(id: 'R01', all: ['s1'], then: 'F01', cf: 0.80, why: 'Rule 1'),
        const Rule(id: 'R02', all: ['s2'], then: 'F01', cf: 0.50, why: 'Rule 2'),
      ];

      final result = engine.infer(workingMemory: wm, rules: rules);

      // combine(0.80, 0.50) = 0.80 + 0.50 * 0.20 = 0.90
      expect(result.topCandidate?.faultId, equals('F01'));
      expect(result.topCf, closeTo(0.90, 0.0001));
      expect(result.topCandidate?.firedRules.length, equals(2));
    });

    test('none condition prevents firing when symptom is TRUE', () {
      final wm = WorkingMemory();
      wm.setTrue('s1');
      wm.setTrue('s_neg');

      final rules = [
        const Rule(
          id: 'R01',
          all: ['s1'],
          none: ['s_neg'],
          then: 'F01',
          cf: 0.80,
          why: 'Rule with negative condition',
        ),
      ];

      final result = engine.infer(workingMemory: wm, rules: rules);
      expect(result.candidates, isEmpty);
    });

    test('none condition allows firing when symptom is FALSE or UNKNOWN', () {
      final wm = WorkingMemory();
      wm.setTrue('s1');
      wm.setFalse('s_neg');

      final rules = [
        const Rule(
          id: 'R01',
          all: ['s1'],
          none: ['s_neg'],
          then: 'F01',
          cf: 0.80,
          why: 'Rule with negative condition',
        ),
      ];

      final result = engine.infer(workingMemory: wm, rules: rules);
      expect(result.candidates.length, equals(1));
    });

    test('any condition fires when at least one condition is TRUE', () {
      final wm = WorkingMemory();
      wm.setTrue('s_any_2', certainty: 0.9);

      final rules = [
        const Rule(
          id: 'R01',
          any: ['s_any_1', 's_any_2'],
          then: 'F01',
          cf: 0.80,
          why: 'Rule with any condition',
        ),
      ];

      final result = engine.infer(workingMemory: wm, rules: rules);
      expect(result.candidates.length, equals(1));
      expect(result.topCf, closeTo(0.80 * 0.9, 0.0001));
    });

    test('excludedFaults skips rules for specified fault (FR10)', () {
      final wm = WorkingMemory();
      wm.setTrue('s1');

      final rules = [
        const Rule(id: 'R01', all: ['s1'], then: 'F01', cf: 0.90, why: 'First candidate'),
        const Rule(id: 'R02', all: ['s1'], then: 'F02', cf: 0.70, why: 'Second candidate'),
      ];

      final result = engine.infer(
        workingMemory: wm,
        rules: rules,
        excludedFaults: {'F01'},
      );

      expect(result.topCandidate?.faultId, equals('F02'));
      expect(result.candidates.any((c) => c.faultId == 'F01'), isFalse);
    });

    test('safety override triggers immediately and prioritizes safety fault', () {
      final wm = WorkingMemory();
      wm.setTrue('overheating');
      wm.setTrue('paper_jam');

      final rules = [
        const Rule(id: 'R01', all: ['paper_jam'], then: 'F01', cf: 0.90, why: 'Jam'),
        const Rule(
          id: 'R71',
          all: ['overheating'],
          then: 'F20',
          cf: 0.99,
          why: 'Smoke or fire hazard',
          safety: true,
        ),
      ];

      final result = engine.infer(workingMemory: wm, rules: rules);

      expect(result.hasSafetyOverride, isTrue);
      expect(result.safetyFaultId, equals('F20'));
      expect(result.topCandidate?.faultId, equals('F20'));
      expect(result.shouldConclude(), isTrue);
    });

    test('conclusion criteria logic', () {
      // Meets criteria: top >= 0.75 and margin >= 0.15
      final confident = InferenceResult(
        candidates: [
          const FaultCandidate(faultId: 'F01', cf: 0.85, firedRules: []),
          const FaultCandidate(faultId: 'F02', cf: 0.65, firedRules: []),
        ],
        firedRules: const [],
      );
      expect(confident.meetsConfidenceCriteria, isTrue);
      expect(confident.shouldConclude(), isTrue);

      // Does not meet criteria: margin too close (0.80 vs 0.70)
      final ambiguous = InferenceResult(
        candidates: [
          const FaultCandidate(faultId: 'F01', cf: 0.80, firedRules: []),
          const FaultCandidate(faultId: 'F02', cf: 0.70, firedRules: []),
        ],
        firedRules: const [],
      );
      expect(ambiguous.meetsConfidenceCriteria, isFalse);
      expect(ambiguous.shouldConclude(), isFalse);

      // Concludes when questionsAsked >= 6
      expect(ambiguous.shouldConclude(questionsAsked: 6), isTrue);

      // Concludes when no useful questions remain
      expect(ambiguous.shouldConclude(noUsefulQuestionsRemaining: true), isTrue);
    });
  });

  group('Explanation Facility (explanation.dart)', () {
    test('how and why explanations provide reasoning transparency', () {
      final symptomsJson = json.encode([
        {'id': 's1', 'label': 'S1', 'category': 'paper', 'synonyms': [], 'question': 'Is s1 true?'},
        {'id': 's2', 'label': 'S2', 'category': 'paper', 'synonyms': [], 'question': 'Is s2 true?'},
      ]);
      final faultsJson = json.encode([
        {'id': 'F01', 'name': 'Fault 1', 'category': 'paper', 'severity': 'low', 'technician': false, 'summary': 'Sum', 'steps': []},
        {'id': 'F02', 'name': 'Fault 2', 'category': 'paper', 'severity': 'low', 'technician': false, 'summary': 'Sum', 'steps': []},
      ]);
      final rulesJson = json.encode([
        {'id': 'R01', 'all': ['s1'], 'then': 'F01', 'cf': 0.80, 'why': 's1 causes F01'},
        {'id': 'R02', 'all': ['s1', 's2'], 'then': 'F02', 'cf': 0.70, 'why': 's1 and s2 cause F02'},
      ]);

      final kb = const KbLoader().load(
        symptomsJson: symptomsJson,
        faultsJson: faultsJson,
        rulesJson: rulesJson,
      );

      final wm = WorkingMemory()..setTrue('s1');
      final inferenceResult = const InferenceEngine().infer(
        workingMemory: wm,
        rules: kb.rules,
      );

      final explanation = ExplanationFacility(kb);

      // Test "how"
      final howF01 = explanation.how('F01', inferenceResult);
      expect(howF01.faultId, 'F01');
      expect(howF01.rules.length, 1);
      expect(howF01.rules.first.ruleId, 'R01');
      expect(howF01.rules.first.why, 's1 causes F01');

      // Test "why"
      final whyS2 = explanation.why('s2');
      expect(whyS2, contains('F02'));
    });
  });

  group('Real 20 Test Scenarios Evaluation (assets/kb/test_scenarios.json)', () {
    test('all 20 scenarios diagnose the expected fault from scenario truth list', () {
      final symptomsFile = File('assets/kb/symptoms.json');
      final faultsFile = File('assets/kb/faults.json');
      final rulesFile = File('assets/kb/rules.json');
      final scenariosFile = File('assets/kb/test_scenarios.json');

      final kb = const KbLoader().load(
        symptomsJson: symptomsFile.readAsStringSync(),
        faultsJson: faultsFile.readAsStringSync(),
        rulesJson: rulesFile.readAsStringSync(),
      );

      final List<dynamic> scenarios =
          json.decode(scenariosFile.readAsStringSync()) as List<dynamic>;

      expect(scenarios.length, greaterThanOrEqualTo(20),
          reason: 'At least 20 evaluation scenarios');

      const engine = InferenceEngine();
      final failures = <String>[];

      for (final raw in scenarios) {
        final scenario = raw as Map<String, dynamic>;
        final id = scenario['id'] as String;
        final utterance = scenario['utterance'] as String;
        final truth = (scenario['truth'] as List<dynamic>).cast<String>();
        final expected = scenario['expected'] as String;

        // Populate working memory with scenario's ground truth facts
        final wm = WorkingMemory.fromKnowledgeBase(kb);
        for (final symptomId in truth) {
          wm.setTrue(symptomId, certainty: 1.0);
        }

        final result = engine.infer(
          workingMemory: wm,
          rules: kb.rules,
        );

        final topCandidate = result.topCandidate;
        final topFault = topCandidate?.faultId;

        if (topFault != expected) {
          failures.add(
            'Scenario $id: utterance="$utterance"\n'
            '  Expected: $expected\n'
            '  Got:      $topFault (CF: ${topCandidate?.cf.toStringAsFixed(2)})\n'
            '  Candidates: ${result.candidates.map((c) => '${c.faultId}:${c.cf.toStringAsFixed(2)}').join(', ')}',
          );
        }
      }

      if (failures.isNotEmpty) {
        // ignore: avoid_print
        print('Scenario Failures:\n${failures.join('\n\n')}');
      }

      expect(failures, isEmpty, reason: 'All test scenarios must match expected fault');
    });
  });
}
