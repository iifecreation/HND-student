// Manages conversational turn loops, questioning transitions, diagnostic resolution, and guided step flows.

import '../engine/explanation.dart';
import '../engine/inference_engine.dart';
import '../engine/working_memory.dart';
import '../knowledge/fault.dart';
import '../knowledge/kb_loader.dart';
import '../knowledge/symptom.dart';
import '../nlu/command_parser.dart';
import '../nlu/symptom_extractor.dart';
import 'dialogue_state.dart';
import 'question_selector.dart';

/// Pure Dart dialogue manager driving the diagnostic turn loop and state machine.
class DialogueManager {
  final KnowledgeBase kb;
  final InferenceEngine inferenceEngine;
  final SymptomExtractor symptomExtractor;
  final CommandParser commandParser;
  final QuestionSelector questionSelector;
  final ExplanationFacility explanationFacility;

  // Session state
  DialogueState _state = DialogueState.idle;
  late WorkingMemory _workingMemory;
  final Set<String> _excludedFaults = {};
  InferenceResult? _lastInferenceResult;
  Symptom? _currentQuestionSymptom;
  FaultCandidate? _currentCandidate;
  Fault? _currentFault;
  int _currentStepIndex = 0;
  int _questionsAsked = 0;
  int _failedExtractionCount = 0;

  DialogueManager({
    required this.kb,
    InferenceEngine? inferenceEngine,
    SymptomExtractor? symptomExtractor,
    CommandParser? commandParser,
    QuestionSelector? questionSelector,
    ExplanationFacility? explanationFacility,
  })  : inferenceEngine = inferenceEngine ?? const InferenceEngine(),
        symptomExtractor =
            symptomExtractor ?? SymptomExtractor.fromKnowledgeBase(kb),
        commandParser = commandParser ?? const CommandParser(),
        questionSelector = questionSelector ?? QuestionSelector(kb),
        explanationFacility =
            explanationFacility ?? ExplanationFacility(kb) {
    _workingMemory = WorkingMemory.fromKnowledgeBase(kb);
  }

  // State inspection getters
  DialogueState get state => _state;
  WorkingMemory get workingMemory => _workingMemory;
  Set<String> get excludedFaults => Set.unmodifiable(_excludedFaults);
  InferenceResult? get lastInferenceResult => _lastInferenceResult;
  Symptom? get currentQuestionSymptom => _currentQuestionSymptom;
  FaultCandidate? get currentCandidate => _currentCandidate;
  Fault? get currentFault => _currentFault;
  int get currentStepIndex => _currentStepIndex;
  int get questionsAsked => _questionsAsked;

  /// Starts or restarts a fresh diagnostic dialogue session.
  DialogueResponse startSession() {
    _state = DialogueState.collecting;
    _workingMemory = WorkingMemory.fromKnowledgeBase(kb);
    _excludedFaults.clear();
    _lastInferenceResult = null;
    _currentQuestionSymptom = null;
    _currentCandidate = null;
    _currentFault = null;
    _currentStepIndex = 0;
    _questionsAsked = 0;
    _failedExtractionCount = 0;

    const greeting =
        'Hello! I am PrinterDoc. What seems to be the problem with your printer?';

    return const DialogueResponse(
      state: DialogueState.collecting,
      spokenText: greeting,
      displayText: greeting,
      quickReplyChips: [
        'Paper jam',
        'Faded print',
        'Printer offline',
        'Not turning on',
      ],
    );
  }

  /// Processes a single user utterance (from voice or text fallback) and advances the state machine.
  DialogueResponse processUtterance(String utterance) {
    final trimmed = utterance.trim();

    // 1. Check for global restart command
    final cmd = commandParser.parseCommand(trimmed);
    if (cmd == UserCommand.startOver) {
      return startSession();
    }

    // 2. Handle state-specific logic
    switch (_state) {
      case DialogueState.idle:
        return startSession();

      case DialogueState.collecting:
        return _handleCollecting(trimmed);

      case DialogueState.questioning:
        return _handleQuestioning(trimmed, cmd);

      case DialogueState.diagnosed:
        return _handleDiagnosed(trimmed, cmd);

      case DialogueState.guiding:
        return _handleGuiding(trimmed, cmd);

      case DialogueState.resolved:
      case DialogueState.escalated:
        return DialogueResponse(
          state: _state,
          spokenText: 'This session is complete. Would you like to start over?',
          displayText: 'This session is complete. Would you like to start over?',
          quickReplyChips: const ['Start over'],
        );
    }
  }

  /// Turn logic for initial symptom collection in free text.
  DialogueResponse _handleCollecting(String utterance) {
    final extracted = symptomExtractor.extractSymptoms(utterance);

    if (extracted.isEmpty) {
      _failedExtractionCount++;
      if (_failedExtractionCount == 1) {
        const text =
            'I did not catch a specific printer symptom. Could you describe what is happening? For example: is paper jammed, is printing faded, or is there an error light?';
        return const DialogueResponse(
          state: DialogueState.collecting,
          spokenText: text,
          displayText: text,
          quickReplyChips: [
            'Paper jam',
            'Faded print',
            'Printer offline',
            'Error light',
          ],
        );
      } else {
        const text = 'Please select a category that best matches your problem:';
        return const DialogueResponse(
          state: DialogueState.collecting,
          spokenText: text,
          displayText: text,
          quickReplyChips: [
            'Paper issues',
            'Print quality',
            'Connectivity',
            'Hardware problem',
          ],
        );
      }
    }

    _failedExtractionCount = 0;

    // Write all extracted facts to working memory
    for (final item in extracted) {
      if (item.isPresent) {
        _workingMemory.setTrue(item.symptomId, certainty: 1.0);
      } else {
        _workingMemory.setFalse(item.symptomId, certainty: 1.0);
      }
    }

    return _evaluateInferenceAndTransition();
  }

  /// Turn logic when waiting for a yes/no/unsure answer to a follow-up question.
  DialogueResponse _handleQuestioning(String utterance, UserCommand cmd) {
    // Explanation inquiries during questioning
    if (cmd == UserCommand.why) {
      if (_currentQuestionSymptom != null) {
        final explanation = explanationFacility.whySpoken(
          _currentQuestionSymptom!.id,
          candidates: _lastInferenceResult?.candidates ?? const [],
        );
        final fullText =
            '$explanation ${_currentQuestionSymptom!.question}';
        return DialogueResponse(
          state: DialogueState.questioning,
          spokenText: fullText,
          displayText: fullText,
          quickReplyChips: const ['Yes', 'No', 'Not sure'],
        );
      }
    }

    final answer = commandParser.parseAnswer(utterance);

    if (answer == UserAnswer.yes) {
      if (_currentQuestionSymptom != null) {
        _workingMemory.setTrue(_currentQuestionSymptom!.id, certainty: 1.0);
      }
    } else if (answer == UserAnswer.no) {
      if (_currentQuestionSymptom != null) {
        _workingMemory.setFalse(_currentQuestionSymptom!.id, certainty: 1.0);
      }
    } else if (answer == UserAnswer.unsure) {
      if (_currentQuestionSymptom != null) {
        _workingMemory.setUnsure(_currentQuestionSymptom!.id);
      }
    } else {
      // Check if user spoke another symptom instead of yes/no
      final extra = symptomExtractor.extractSymptoms(utterance);
      if (extra.isNotEmpty) {
        for (final item in extra) {
          if (item.isPresent) {
            _workingMemory.setTrue(item.symptomId, certainty: 1.0);
          } else {
            _workingMemory.setFalse(item.symptomId, certainty: 1.0);
          }
        }
      } else {
        final rePrompt =
            'Please answer yes, no, or not sure: ${_currentQuestionSymptom?.question ?? "Is that symptom present?"}';
        return DialogueResponse(
          state: DialogueState.questioning,
          spokenText: rePrompt,
          displayText: rePrompt,
          quickReplyChips: const ['Yes', 'No', 'Not sure'],
        );
      }
    }

    return _evaluateInferenceAndTransition();
  }

  /// Runs inference, evaluates conclusion criteria, and chooses next question or diagnosis.
  DialogueResponse _evaluateInferenceAndTransition() {
    _lastInferenceResult = inferenceEngine.infer(
      workingMemory: _workingMemory,
      rules: kb.rules,
      excludedFaults: _excludedFaults,
    );

    final nextQuestion = questionSelector.selectNextQuestion(
      workingMemory: _workingMemory,
      candidates: _lastInferenceResult!.candidates,
      excludedFaults: _excludedFaults,
    );

    final conclude = _lastInferenceResult!.shouldConclude(
      questionsAsked: _questionsAsked,
      noUsefulQuestionsRemaining: nextQuestion == null,
    );

    if (conclude && _lastInferenceResult!.candidates.isNotEmpty) {
      return _transitionToDiagnosed();
    }

    if (nextQuestion != null && _questionsAsked < 6) {
      _state = DialogueState.questioning;
      _currentQuestionSymptom = nextQuestion;
      _questionsAsked++;

      return DialogueResponse(
        state: DialogueState.questioning,
        spokenText: nextQuestion.question,
        displayText: nextQuestion.question,
        quickReplyChips: const ['Yes', 'No', 'Not sure'],
      );
    }

    // Exhausted questions or candidates
    if (_lastInferenceResult!.candidates.isNotEmpty) {
      return _transitionToDiagnosed();
    }

    _state = DialogueState.escalated;
    const noMatchText =
        'I could not determine the exact fault with certainty. Please inspect the printer or consult a technician.';
    return const DialogueResponse(
      state: DialogueState.escalated,
      spokenText: noMatchText,
      displayText: noMatchText,
      quickReplyChips: ['Start over'],
    );
  }

  /// Transitions to the diagnosed state and formats spoken summary and repair proposal.
  DialogueResponse _transitionToDiagnosed() {
    _state = DialogueState.diagnosed;
    _currentCandidate = _lastInferenceResult!.topCandidate!;
    _currentFault = kb.getFault(_currentCandidate!.faultId);

    final faultName = _currentFault?.name ?? _currentCandidate!.faultId;
    final confidencePct = (_currentCandidate!.cf * 100).toInt();
    final summary = _currentFault?.summary ?? '';
    final isSafety = _lastInferenceResult!.hasSafetyOverride;
    final isTech = _currentFault?.technician ?? false;

    final alternatives = _lastInferenceResult!.candidates.skip(1).take(3).toList();

    String spoken;
    String display;

    if (isSafety) {
      spoken =
          'Safety alert: $faultName. $summary Please switch off and unplug the printer immediately.';
      display = '⚠️ **SAFETY HAZARD DETECTED: $faultName**\n\n$summary\n\n'
          'Switch off and unplug the printer immediately. Contact a technician.';
      _state = DialogueState.escalated;
      return DialogueResponse(
        state: DialogueState.escalated,
        spokenText: spoken,
        displayText: display,
        candidate: _currentCandidate,
        fault: _currentFault,
        alternatives: alternatives,
        isSafetyAlert: true,
        quickReplyChips: const ['Start over'],
      );
    }

    spoken =
        'Diagnosis: $faultName, with $confidencePct% confidence. $summary '
        '${isTech ? "Note that a technician is recommended for this issue. " : ""}'
        'Shall I walk you through the fix?';

    display = '**Diagnosis:** $faultName ($confidencePct% confidence)\n\n'
        '$summary\n\n'
        '${isTech ? "⚠️ *Technician assistance is recommended.*\n\n" : ""}'
        'Shall I walk you through the fix?';

    return DialogueResponse(
      state: DialogueState.diagnosed,
      spokenText: spoken,
      displayText: display,
      candidate: _currentCandidate,
      fault: _currentFault,
      alternatives: alternatives,
      quickReplyChips: const ['Yes, walk me through it', 'No, thank you'],
    );
  }

  /// Turn logic when user is presented with the diagnosis.
  DialogueResponse _handleDiagnosed(String utterance, UserCommand cmd) {
    final answer = commandParser.parseAnswer(utterance);

    if (answer == UserAnswer.yes ||
        cmd == UserCommand.next ||
        utterance.toLowerCase().contains('walk me through') ||
        utterance.toLowerCase().contains('guide')) {
      if (_currentFault != null && _currentFault!.steps.isNotEmpty) {
        _state = DialogueState.guiding;
        _currentStepIndex = 0;
        return _buildGuidingResponse();
      } else {
        _state = DialogueState.resolved;
        const msg =
            'No further manual steps are required. Let me know if you need anything else.';
        return const DialogueResponse(
          state: DialogueState.resolved,
          spokenText: msg,
          displayText: msg,
          quickReplyChips: ['Start over'],
        );
      }
    }

    if (answer == UserAnswer.no || cmd == UserCommand.stop) {
      _state = DialogueState.resolved;
      const msg = 'Understood. Let me know if you need help with anything else.';
      return const DialogueResponse(
        state: DialogueState.resolved,
        spokenText: msg,
        displayText: msg,
        quickReplyChips: ['Start over'],
      );
    }

    // Default re-prompt
    const rePrompt = 'Shall I walk you through the fix step by step?';
    return const DialogueResponse(
      state: DialogueState.diagnosed,
      spokenText: rePrompt,
      displayText: rePrompt,
      quickReplyChips: ['Yes, walk me through it', 'No, thank you'],
    );
  }

  /// Turn logic during step-by-step fix guidance.
  DialogueResponse _handleGuiding(String utterance, UserCommand cmd) {
    final steps = _currentFault?.steps ?? const [];
    final totalSteps = steps.length;
    final isOnLastStep = (_currentStepIndex >= totalSteps - 1);

    // If on the last step, handle outcome question: "Did that fix it?"
    if (isOnLastStep) {
      final answer = commandParser.parseAnswer(utterance);

      if (cmd == UserCommand.fixWorked || answer == UserAnswer.yes) {
        _state = DialogueState.resolved;
        const msg = 'Great! Glad the issue has been resolved.';
        return const DialogueResponse(
          state: DialogueState.resolved,
          spokenText: msg,
          displayText: msg,
          quickReplyChips: ['Start over'],
        );
      }

      if (cmd == UserCommand.fixFailed || answer == UserAnswer.no) {
        // FR10: Exclude this fault and continue with next candidate
        if (_currentCandidate != null) {
          _excludedFaults.add(_currentCandidate!.faultId);
        }

        // Re-evaluate inference with exclusion
        _lastInferenceResult = inferenceEngine.infer(
          workingMemory: _workingMemory,
          rules: kb.rules,
          excludedFaults: _excludedFaults,
        );

        if (_lastInferenceResult!.candidates.isNotEmpty) {
          _currentCandidate = _lastInferenceResult!.topCandidate!;
          _currentFault = kb.getFault(_currentCandidate!.faultId);
          _state = DialogueState.diagnosed;

          final nextName = _currentFault?.name ?? _currentCandidate!.faultId;
          final pct = (_currentCandidate!.cf * 100).toInt();
          final prompt =
              'Since that did not work, the next candidate is $nextName ($pct% confidence). '
              'Shall I walk you through this fix?';

          return DialogueResponse(
            state: DialogueState.diagnosed,
            spokenText: prompt,
            displayText: prompt,
            candidate: _currentCandidate,
            fault: _currentFault,
            alternatives:
                _lastInferenceResult!.candidates.skip(1).take(3).toList(),
            quickReplyChips: const ['Yes, walk me through it', 'No, thank you'],
          );
        } else {
          _state = DialogueState.escalated;
          const msg =
              'All recommended fixes have been attempted. Please consult a qualified technician.';
          return const DialogueResponse(
            state: DialogueState.escalated,
            spokenText: msg,
            displayText: msg,
            quickReplyChips: ['Start over'],
          );
        }
      }
    }

    // Step navigation commands
    if (cmd == UserCommand.repeat) {
      return _buildGuidingResponse();
    }

    if (cmd == UserCommand.back && _currentStepIndex > 0) {
      _currentStepIndex--;
      return _buildGuidingResponse();
    }

    if (cmd == UserCommand.next || utterance.toLowerCase().contains('next')) {
      if (_currentStepIndex < totalSteps - 1) {
        _currentStepIndex++;
        return _buildGuidingResponse();
      }
    }

    if (cmd == UserCommand.stop) {
      _state = DialogueState.resolved;
      const msg = 'Troubleshooting paused. Let me know if you need more help.';
      return const DialogueResponse(
        state: DialogueState.resolved,
        spokenText: msg,
        displayText: msg,
        quickReplyChips: ['Start over'],
      );
    }

    return _buildGuidingResponse();
  }

  /// Builds structured response for the current step in guiding state.
  DialogueResponse _buildGuidingResponse() {
    final steps = _currentFault?.steps ?? const [];
    final totalSteps = steps.length;
    final stepNum = _currentStepIndex + 1;
    final stepText =
        _currentStepIndex < totalSteps ? steps[_currentStepIndex] : '';

    final isOnLastStep = (_currentStepIndex >= totalSteps - 1);

    String spoken;
    String display;
    List<String> chips;

    if (isOnLastStep) {
      spoken = 'Step $stepNum of $totalSteps: $stepText. Did that fix it?';
      display = '**Step $stepNum of $totalSteps:**\n$stepText\n\n*Did that fix it?*';
      chips = const ['Yes, it worked', 'No, still broken', 'Repeat'];
    } else {
      spoken = 'Step $stepNum of $totalSteps: $stepText.';
      display = '**Step $stepNum of $totalSteps:**\n$stepText';
      chips = const ['Next', 'Repeat', 'Back', 'Stop'];
    }

    return DialogueResponse(
      state: DialogueState.guiding,
      spokenText: spoken,
      displayText: display,
      candidate: _currentCandidate,
      fault: _currentFault,
      currentStepIndex: _currentStepIndex,
      totalSteps: totalSteps,
      quickReplyChips: chips,
    );
  }
}
