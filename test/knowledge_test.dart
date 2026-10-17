// Unit tests for the knowledge base layer: models, loader, and validator.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_doc/knowledge/fault.dart';
import 'package:printer_doc/knowledge/kb_loader.dart';
import 'package:printer_doc/knowledge/kb_validator.dart';
import 'package:printer_doc/knowledge/rule.dart';
import 'package:printer_doc/knowledge/symptom.dart';

void main() {
  group('Knowledge Domain Models', () {
    test('Symptom fromJson and toJson preserves data', () {
      final json = {
        'id': 'test_symptom',
        'label': 'Test Symptom',
        'category': 'paper',
        'synonyms': ['jam', 'paper stuck'],
        'question': 'Is paper jammed?',
        'excludes': ['other_symptom'],
      };

      final symptom = Symptom.fromJson(json);
      expect(symptom.id, 'test_symptom');
      expect(symptom.label, 'Test Symptom');
      expect(symptom.category, 'paper');
      expect(symptom.synonyms, ['jam', 'paper stuck']);
      expect(symptom.question, 'Is paper jammed?');
      expect(symptom.excludes, ['other_symptom']);

      final serialized = symptom.toJson();
      expect(serialized, json);
      expect(symptom, equals(Symptom.fromJson(json)));
    });

    test('Fault fromJson and toJson preserves data', () {
      final json = {
        'id': 'F99',
        'name': 'Test Fault',
        'category': 'hardware',
        'severity': 'high',
        'technician': true,
        'summary': 'Test summary description.',
        'steps': ['Step 1: Check power.', 'Step 2: Reset.'],
      };

      final fault = Fault.fromJson(json);
      expect(fault.id, 'F99');
      expect(fault.name, 'Test Fault');
      expect(fault.severity, 'high');
      expect(fault.technician, isTrue);
      expect(fault.steps.length, 2);

      final serialized = fault.toJson();
      expect(serialized, json);
      expect(fault, equals(Fault.fromJson(json)));
    });

    test('Rule fromJson and toJson preserves data', () {
      final json = {
        'id': 'R99',
        'all': ['s1', 's2'],
        'any': ['s3'],
        'none': ['s4'],
        'then': 'F99',
        'cf': 0.85,
        'why': 'Because s1 and s2 occurred.',
        'safety': true,
      };

      final rule = Rule.fromJson(json);
      expect(rule.id, 'R99');
      expect(rule.all, ['s1', 's2']);
      expect(rule.any, ['s3']);
      expect(rule.none, ['s4']);
      expect(rule.then, 'F99');
      expect(rule.cf, 0.85);
      expect(rule.why, 'Because s1 and s2 occurred.');
      expect(rule.safety, isTrue);

      final serialized = rule.toJson();
      expect(serialized, json);
      expect(rule, equals(Rule.fromJson(json)));
    });
  });

  group('KbValidator Unit Checks', () {
    const validator = KbValidator();

    test('flags duplicate symptom IDs', () {
      final symptoms = [
        const Symptom(
          id: 'dup_symptom',
          label: 'S1',
          category: 'paper',
          synonyms: [],
          question: 'Q1',
        ),
        const Symptom(
          id: 'dup_symptom',
          label: 'S2',
          category: 'paper',
          synonyms: [],
          question: 'Q2',
        ),
      ];

      final result = validator.validate(
        symptoms: symptoms,
        faults: [],
        rules: [],
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.message.contains('Duplicate symptom ID')),
        isTrue,
      );
    });

    test('flags duplicate fault IDs', () {
      final faults = [
        const Fault(
          id: 'F01',
          name: 'Fault 1',
          category: 'paper',
          severity: 'low',
          technician: false,
          summary: 'sum1',
          steps: [],
        ),
        const Fault(
          id: 'F01',
          name: 'Fault 2',
          category: 'paper',
          severity: 'low',
          technician: false,
          summary: 'sum2',
          steps: [],
        ),
      ];

      final result = validator.validate(
        symptoms: [],
        faults: faults,
        rules: [],
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.message.contains('Duplicate fault ID')),
        isTrue,
      );
    });

    test('flags duplicate rule IDs', () {
      final symptoms = [
        const Symptom(
          id: 's1',
          label: 'S1',
          category: 'paper',
          synonyms: [],
          question: 'Q1',
        ),
      ];
      final faults = [
        const Fault(
          id: 'F01',
          name: 'F1',
          category: 'paper',
          severity: 'low',
          technician: false,
          summary: 'sum',
          steps: [],
        ),
      ];
      final rules = [
        const Rule(id: 'R01', all: ['s1'], then: 'F01', cf: 0.8, why: 'w1'),
        const Rule(id: 'R01', all: ['s1'], then: 'F01', cf: 0.5, why: 'w2'),
      ];

      final result = validator.validate(
        symptoms: symptoms,
        faults: faults,
        rules: rules,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.message.contains('Duplicate rule ID')),
        isTrue,
      );
    });

    test('flags rules with empty conditions', () {
      final faults = [
        const Fault(
          id: 'F01',
          name: 'F1',
          category: 'paper',
          severity: 'low',
          technician: false,
          summary: 'sum',
          steps: [],
        ),
      ];
      final rules = [
        const Rule(
          id: 'R01',
          all: [],
          any: [],
          none: [],
          then: 'F01',
          cf: 0.5,
          why: 'empty',
        ),
      ];

      final result = validator.validate(
        symptoms: [],
        faults: faults,
        rules: rules,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.message.contains('empty conditions')),
        isTrue,
      );
    });

    test('flags rules with CF out of bounds', () {
      final symptoms = [
        const Symptom(
          id: 's1',
          label: 'S1',
          category: 'paper',
          synonyms: [],
          question: 'Q1',
        ),
      ];
      final faults = [
        const Fault(
          id: 'F01',
          name: 'F1',
          category: 'paper',
          severity: 'low',
          technician: false,
          summary: 'sum',
          steps: [],
        ),
      ];
      final rules = [
        const Rule(id: 'R01', all: ['s1'], then: 'F01', cf: 1.5, why: 'too high'),
        const Rule(id: 'R02', all: ['s1'], then: 'F01', cf: -0.1, why: 'too low'),
      ];

      final result = validator.validate(
        symptoms: symptoms,
        faults: faults,
        rules: rules,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.where((e) => e.message.contains('Certainty factor')).length,
        2,
      );
    });

    test('flags rules referencing unknown symptoms or faults', () {
      final symptoms = [
        const Symptom(
          id: 's1',
          label: 'S1',
          category: 'paper',
          synonyms: [],
          question: 'Q1',
        ),
      ];
      final faults = [
        const Fault(
          id: 'F01',
          name: 'F1',
          category: 'paper',
          severity: 'low',
          technician: false,
          summary: 'sum',
          steps: [],
        ),
      ];
      final rules = [
        const Rule(
          id: 'R01',
          all: ['unknown_symptom'],
          then: 'F01',
          cf: 0.8,
          why: 'w1',
        ),
        const Rule(
          id: 'R02',
          all: ['s1'],
          then: 'unknown_fault',
          cf: 0.8,
          why: 'w2',
        ),
      ];

      final result = validator.validate(
        symptoms: symptoms,
        faults: faults,
        rules: rules,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.message.contains('unknown symptom ID in all')),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.message.contains('unknown fault ID')),
        isTrue,
      );
    });
  });

  group('Real Knowledge Base Assets Validation', () {
    test('loads real assets/kb/ files and asserts validator reports zero errors', () {
      final symptomsFile = File('assets/kb/symptoms.json');
      final faultsFile = File('assets/kb/faults.json');
      final rulesFile = File('assets/kb/rules.json');

      expect(symptomsFile.existsSync(), isTrue, reason: 'symptoms.json exists');
      expect(faultsFile.existsSync(), isTrue, reason: 'faults.json exists');
      expect(rulesFile.existsSync(), isTrue, reason: 'rules.json exists');

      final symptomsJson = symptomsFile.readAsStringSync();
      final faultsJson = faultsFile.readAsStringSync();
      final rulesJson = rulesFile.readAsStringSync();

      const loader = KbLoader();
      final kb = loader.load(
        symptomsJson: symptomsJson,
        faultsJson: faultsJson,
        rulesJson: rulesJson,
      );

      // Verify asset quantities as documented in SPEC
      expect(kb.symptoms.length, equals(74), reason: '74 symptoms expected');
      expect(kb.faults.length, equals(54), reason: '54 faults expected');
      expect(kb.rules.length, equals(124), reason: '124 rules expected');

      // Validate the real knowledge base
      const validator = KbValidator();
      final result = validator.validateKnowledgeBase(kb);

      if (!result.isValid) {
        // Print errors to facilitate debugging if any
        for (final error in result.errors) {
          // ignore: avoid_print
          print('Validation Error: $error');
        }
      }

      expect(result.isValid, isTrue, reason: 'Validator reports zero errors');
      expect(result.errors, isEmpty);
    });
  });
}
