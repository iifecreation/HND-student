// Guards against synonym collisions: for every evaluation scenario, the
// symptom extractor must not report a symptom as present unless it is in
// that scenario's truth list. Fuzzy matching allows one wrong letter per
// word, so a new synonym can silently match an ordinary word (for example
// "printer beeps" matched "printer keeps"). This test catches that.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_doc/knowledge/kb_loader.dart';
import 'package:printer_doc/nlu/symptom_extractor.dart';

void main() {
  test('no scenario utterance extracts a symptom outside its truth list', () {
    final kb = const KbLoader().load(
      symptomsJson: File('assets/kb/symptoms.json').readAsStringSync(),
      faultsJson: File('assets/kb/faults.json').readAsStringSync(),
      rulesJson: File('assets/kb/rules.json').readAsStringSync(),
    );
    final extractor = SymptomExtractor(kb.symptomList);
    final scenarios = jsonDecode(
      File('assets/kb/test_scenarios.json').readAsStringSync(),
    ) as List<dynamic>;

    final problems = <String>[];
    for (final raw in scenarios) {
      final scenario = raw as Map<String, dynamic>;
      final truth = (scenario['truth'] as List<dynamic>).cast<String>().toSet();
      final utterance = scenario['utterance'] as String;

      for (final found in extractor.extractSymptoms(utterance)) {
        if (found.isPresent && !truth.contains(found.symptomId)) {
          problems.add('${scenario['id']}: "${found.matchedText}" was read as '
              '${found.symptomId} in "$utterance"');
        }
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
