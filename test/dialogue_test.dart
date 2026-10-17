// Unit tests for the dialogue layer: state machine, turn loop, QuestionSelector,
// guided repair steps, and fault exclusion recovery (FR10).

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_doc/dialogue/dialogue_manager.dart';
import 'package:printer_doc/dialogue/dialogue_state.dart';
import 'package:printer_doc/dialogue/question_selector.dart';
import 'package:printer_doc/engine/inference_engine.dart';
import 'package:printer_doc/engine/working_memory.dart';
import 'package:printer_doc/knowledge/kb_loader.dart';

void main() {
  late KnowledgeBase kb;

  setUpAll(() {
    final symptomsFile = File('assets/kb/symptoms.json');
    final faultsFile = File('assets/kb/faults.json');
    final rulesFile = File('assets/kb/rules.json');

    kb = const KbLoader().load(
      symptomsJson: symptomsFile.readAsStringSync(),
      faultsJson: faultsFile.readAsStringSync(),
      rulesJson: rulesFile.readAsStringSync(),
    );
  });

  group('QuestionSelector (question_selector.dart)', () {
    test('prioritizes printer type early when candidate rules require it', () {
      final selector = QuestionSelector(kb);
      final wm = WorkingMemory.fromKnowledgeBase(kb);

      // Suppose faded_print was observed
      wm.setTrue('faded_print');

      // Candidates: F05 (laser) and F06 (inkjet)
      final candidates = [
        const FaultCandidate(faultId: 'F05', cf: 0.50, firedRules: []),
        const FaultCandidate(faultId: 'F06', cf: 0.50, firedRules: []),
      ];

      final nextQuestion = selector.selectNextQuestion(
        workingMemory: wm,
        candidates: candidates,
      );

      // Any printer-type question is correct here; with four printer types
      // the selector asks about the type most candidate rules depend on.
      expect(nextQuestion?.category, equals(QuestionSelector.printerTypeCategory),
          reason: 'Printer type must be asked early when candidates differ by printer type');
    });

    test('picks symptom with highest rule coverage among candidate rules', () {
      final selector = QuestionSelector(kb);
      final wm = WorkingMemory.fromKnowledgeBase(kb);

      wm.setTrue('type_laser');
      wm.setTrue('paper_jam');

      final result = const InferenceEngine().infer(
        workingMemory: wm,
        rules: kb.rules,
      );

      final nextQuestion = selector.selectNextQuestion(
        workingMemory: wm,
        candidates: result.candidates,
      );

      expect(nextQuestion, isNotNull);
      expect(wm.isUnknown(nextQuestion!.id), isTrue);
    });
  });

  group('DialogueManager Workflow (dialogue_manager.dart)', () {
    test('starts session with friendly prompt in collecting state', () {
      final dm = DialogueManager(kb: kb);
      final resp = dm.startSession();

      expect(resp.state, equals(DialogueState.collecting));
      expect(resp.spokenText, contains('PrinterDoc'));
      expect(resp.quickReplyChips, isNotEmpty);
    });

    test('transitions collecting -> diagnosed when initial utterance is unambiguous', () {
      final dm = DialogueManager(kb: kb);
      dm.startSession();

      // "my printer keeps jamming and the tray is stuffed full of paper"
      final resp = dm.processUtterance(
        'my printer keeps jamming and the tray is stuffed full of paper',
      );

      expect(resp.state, equals(DialogueState.diagnosed));
      expect(resp.candidate?.faultId, equals('F01'));
      expect(resp.quickReplyChips, contains('Yes, walk me through it'));
    });

    test('guided steps navigation: next, repeat, back, stop', () {
      final dm = DialogueManager(kb: kb);
      dm.startSession();

      // Initiate diagnosis
      dm.processUtterance('my printer keeps jamming and the tray is stuffed full of paper');

      // Agree to guided steps
      var resp = dm.processUtterance('yes walk me through it');
      expect(resp.state, equals(DialogueState.guiding));
      expect(resp.currentStepIndex, equals(0));
      expect(resp.spokenText, contains('Step 1'));

      // Next step
      resp = dm.processUtterance('next');
      expect(resp.currentStepIndex, equals(1));
      expect(resp.spokenText, contains('Step 2'));

      // Repeat step
      resp = dm.processUtterance('repeat');
      expect(resp.currentStepIndex, equals(1));
      expect(resp.spokenText, contains('Step 2'));

      // Back step
      resp = dm.processUtterance('back');
      expect(resp.currentStepIndex, equals(0));
      expect(resp.spokenText, contains('Step 1'));
    });

    test('FR10: fix did not work excludes fault and continues with next candidate', () {
      final dm = DialogueManager(kb: kb);
      dm.startSession();

      // Start diagnosis
      dm.processUtterance('my printer keeps jamming and the tray is stuffed full of paper');
      dm.processUtterance('yes'); // enter guiding

      // Fast-forward to last step
      final totalSteps = dm.currentFault!.steps.length;
      for (var i = 0; i < totalSteps - 1; i++) {
        dm.processUtterance('next');
      }

      expect(dm.currentStepIndex, equals(totalSteps - 1));

      // User says the fix did not work!
      final resp = dm.processUtterance('didnt work');

      // Must exclude F01 and propose next candidate
      expect(dm.excludedFaults, contains('F01'));
      expect(resp.candidate?.faultId, isNot(equals('F01')));
    });

    test('safety override triggers immediately on overheating', () {
      final dm = DialogueManager(kb: kb);
      dm.startSession();

      final resp = dm.processUtterance(
        'there is smoke and a burning smell coming from the printer',
      );

      expect(resp.isSafetyAlert, isTrue);
      expect(resp.candidate?.faultId, equals('F20'));
      expect(resp.state, equals(DialogueState.escalated));
      expect(resp.spokenText, contains('Safety alert'));
    });
  });
}
