// Automated evaluation harness running knowledge base test scenarios and computing diagnostic accuracy metrics.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_doc/dialogue/dialogue_manager.dart';
import 'package:printer_doc/dialogue/dialogue_state.dart';
import 'package:printer_doc/knowledge/kb_loader.dart';

void main() {
  test('Run all evaluation scenarios through DialogueManager with simulated user', () {
    final symptomsFile = File('assets/kb/symptoms.json');
    final faultsFile = File('assets/kb/faults.json');
    final rulesFile = File('assets/kb/rules.json');
    final scenariosFile = File('assets/kb/test_scenarios.json');

    final kb = const KbLoader().load(
      symptomsJson: symptomsFile.readAsStringSync(),
      faultsJson: faultsFile.readAsStringSync(),
      rulesJson: rulesFile.readAsStringSync(),
    );

    final List<dynamic> rawScenarios =
        json.decode(scenariosFile.readAsStringSync()) as List<dynamic>;

    var top1Correct = 0;
    var top3Correct = 0;
    var totalQuestions = 0;
    var totalElapsedMs = 0;

    final rows = <String>[];

    for (final raw in rawScenarios) {
      final scenario = raw as Map<String, dynamic>;
      final id = scenario['id'] as String;
      final utterance = scenario['utterance'] as String;
      final truth = (scenario['truth'] as List<dynamic>).cast<String>().toSet();
      final expected = scenario['expected'] as String;

      final dm = DialogueManager(kb: kb);
      dm.startSession();

      final stopwatch = Stopwatch()..start();

      // Feed initial user utterance
      dm.processUtterance(utterance);

      // Simulated user loop: answers follow-up questions according to ground truth
      var safetyTurns = 0;
      while (dm.state == DialogueState.questioning && safetyTurns < 12) {
        safetyTurns++;
        final qSymptom = dm.currentQuestionSymptom;
        if (qSymptom == null) break;

        final isTruth = truth.contains(qSymptom.id);
        dm.processUtterance(isTruth ? 'yes' : 'no');
      }

      stopwatch.stop();

      final diagnosedFault = dm.currentCandidate?.faultId ?? 'NONE';
      final top3Faults = dm.lastInferenceResult?.candidates
              .take(3)
              .map((c) => c.faultId)
              .toList() ??
          const [];

      final isTop1 = (diagnosedFault == expected);
      final isTop3 = top3Faults.contains(expected);

      if (isTop1) top1Correct++;
      if (isTop3) top3Correct++;
      totalQuestions += dm.questionsAsked;
      totalElapsedMs += stopwatch.elapsedMilliseconds;

      final top1Str = isTop1 ? 'PASS' : 'FAIL';
      final top3Str = isTop3 ? 'PASS' : 'FAIL';
      final timeStr = '${stopwatch.elapsedMilliseconds}ms';

      rows.add(
        '${id.padRight(5)} | ${expected.padRight(8)} | ${diagnosedFault.padRight(9)} | '
        '${top1Str.padRight(5)} | ${top3Str.padRight(5)} | '
        '${dm.questionsAsked.toString().padRight(9)} | ${timeStr.padRight(8)} | $utterance',
      );
    }

    final total = rawScenarios.length;
    final top1Pct = (top1Correct / total) * 100.0;
    final top3Pct = (top3Correct / total) * 100.0;
    final avgQuestions = totalQuestions / total;
    final avgTimeMs = totalElapsedMs / total;

    final buffer = StringBuffer();
    buffer.writeln('\n========================================================================================================================');
    buffer.writeln('SCENARIO EVALUATION RESULTS (Simulated User over DialogueManager)');
    buffer.writeln('========================================================================================================================');
    buffer.writeln('ID    | Expected | Diagnosed | Top-1 | Top-3 | Questions | Time     | Utterance');
    buffer.writeln('------+----------+-----------+-------+-------+-----------+----------+---------------------------------------------------');
    for (final row in rows) {
      buffer.writeln(row);
    }
    buffer.writeln('========================================================================================================================');
    buffer.writeln('METRICS SUMMARY:');
    buffer.writeln('  Total Scenarios:          $total');
    buffer.writeln('  Top-1 Diagnostic Accuracy: ${top1Pct.toStringAsFixed(1)}% ($top1Correct / $total)');
    buffer.writeln('  Top-3 Diagnostic Accuracy: ${top3Pct.toStringAsFixed(1)}% ($top3Correct / $total)');
    buffer.writeln('  Average Questions Asked:  ${avgQuestions.toStringAsFixed(2)}');
    buffer.writeln('  Average Elapsed Time:     ${avgTimeMs.toStringAsFixed(2)} ms');
    buffer.writeln('========================================================================================================================\n');

    // ignore: avoid_print
    print(buffer.toString());

    expect(top1Correct, equals(total),
        reason: 'All $total scenarios must achieve Top-1 diagnosis without altering truth or expected');
    expect(top3Correct, equals(total),
        reason: 'All $total scenarios must be in Top-3');
  });
}
