// Models the dialogue manager finite state machine states and structured turn responses.

import '../engine/inference_engine.dart';
import '../knowledge/fault.dart';

/// Finite state machine states for the conversational diagnostic session.
enum DialogueState {
  /// Session has not started or has been reset.
  idle,

  /// Initial state awaiting free-text or spoken problem description.
  collecting,

  /// System is awaiting yes/no/unsure answer to a follow-up question.
  questioning,

  /// Diagnosis concluded; presenting fault findings and proposing guided steps.
  diagnosed,

  /// Walking the user through step-by-step fix procedures.
  guiding,

  /// Repair succeeded; session completed.
  resolved,

  /// Hardware safety emergency or technician intervention required.
  escalated,
}

/// Structured response returned by the pure-Dart dialogue manager on every turn.
///
/// Contains spoken audio text, visual chat transcript text, and contextual UI chips.
class DialogueResponse {
  /// The current state of the dialogue state machine.
  final DialogueState state;

  /// Text to be read aloud by Text-To-Speech (TTS).
  final String spokenText;

  /// Text to be rendered in the chat bubble UI.
  final String displayText;

  /// Contextual quick-reply suggestion chips (e.g. ['Yes', 'No', 'Not sure']).
  final List<String> quickReplyChips;

  /// The active diagnosed fault candidate, if diagnosed or in guiding.
  final FaultCandidate? candidate;

  /// The active fault definition with steps and summary, if available.
  final Fault? fault;

  /// Current 0-based fix step index if in guiding state.
  final int currentStepIndex;

  /// Total number of fix steps for the current fault.
  final int totalSteps;

  /// Ranked alternative candidate faults for display.
  final List<FaultCandidate> alternatives;

  /// Flag indicating if an immediate safety override (e.g. F20 overheating) occurred.
  final bool isSafetyAlert;

  const DialogueResponse({
    required this.state,
    required this.spokenText,
    required this.displayText,
    this.quickReplyChips = const [],
    this.candidate,
    this.fault,
    this.currentStepIndex = 0,
    this.totalSteps = 0,
    this.alternatives = const [],
    this.isSafetyAlert = false,
  });

  @override
  String toString() =>
      'DialogueResponse(state: $state, spoken: "$spokenText", chips: $quickReplyChips)';
}
