// Coordinates dialogue management, speech I/O, session logging, and UI state notifications.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../app/kb_asset_loader.dart';
import '../../app/service_locator.dart';
import '../../data/session_logger.dart';
import '../../data/settings_repository.dart';
import '../../dialogue/dialogue_manager.dart';
import '../../dialogue/dialogue_state.dart';
import '../../engine/inference_engine.dart';
import '../../knowledge/fault.dart';
import '../../knowledge/kb_loader.dart';
import '../../voice/permissions.dart';
import '../../voice/speech_recognizer_service.dart';
import '../../voice/tts_service.dart';

/// Individual message in the chat-style diagnostic transcript.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? faultId;
  final double? confidence;
  final bool isSafetyAlert;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.faultId,
    this.confidence,
    this.isSafetyAlert = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Kinds of voice problem the Home screen can show a banner for.
enum VoiceIssueKind { micPermission, modelMissing, ttsVoiceMissing, listenFailed }

/// A user-facing voice problem plus plain instructions on how to fix it.
/// The app still works through typing and the chips while one is showing.
class VoiceIssue {
  final VoiceIssueKind kind;
  final String message;
  const VoiceIssue(this.kind, this.message);
}

/// Primary ViewModel connecting UI to the expert system core and voice pipelines.
class DiagnosisViewModel extends ChangeNotifier {
  final ServiceLocator _services = ServiceLocator();
  DialogueManager? _dialogueManager;
  KnowledgeBase? _kb;

  final List<ChatMessage> _messages = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String _livePartialText = '';
  DateTime? _speechStartTime;
  DateTime? _sessionStartTime;
  VoiceIssue? _voiceIssue;

  // Real time spent inside the dialogue manager for this session, summed
  // over every turn. Logged so evaluation figures are measured, not invented.
  int _sessionInferenceMicros = 0;

  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _finalSub;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get livePartialText => _livePartialText;
  VoiceIssue? get voiceIssue => _voiceIssue;

  DialogueState get state => _dialogueManager?.state ?? DialogueState.idle;
  String? get currentQuestion =>
      _dialogueManager?.currentQuestionSymptom?.question;
  String? get currentQuestionSymptomId =>
      _dialogueManager?.currentQuestionSymptom?.id;
  FaultCandidate? get currentCandidate => _dialogueManager?.currentCandidate;
  Fault? get currentFault => _dialogueManager?.currentFault;
  List<FaultCandidate> get candidateRankings =>
      _dialogueManager?.lastInferenceResult?.candidates ?? [];
  int get currentStepIndex => _dialogueManager?.currentStepIndex ?? 0;
  List<String> get currentSteps => _dialogueManager?.currentFault?.steps ?? [];

  SpeechRecognizerService get recognizer => _services.speechRecognizer;
  TtsService get tts => _services.tts;
  SessionLogger get logger => _services.sessionLogger;
  SettingsRepository get settingsRepo => _services.settingsRepository;

  bool get isListening => recognizer.isListening;
  bool get isSpeaking => tts.isSpeaking;

  /// Initializes the Knowledge Base, Voice pipelines, and settings.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Load Knowledge Base from assets
      _kb = _services.kb ?? await FlutterKbAssetLoader.loadFromAssets();
      _services.setKnowledgeBase(_kb!);

      // 2. Initialize dialogue manager
      _dialogueManager = DialogueManager(kb: _kb!);

      // 3. Initialize TTS and load user settings
      final settings = await settingsRepo.getSettings();
      await tts.initialize();
      await tts.setSpeechRate(settings.speechRate);

      // Wire TTS completion for half-duplex auto-listening
      tts.onSpeechStarted = () {
        if (recognizer.isListening) {
          recognizer.stopListening();
          notifyListeners();
        }
      };

      tts.onSpeechCompleted = () async {
        final currentSettings = await settingsRepo.getSettings();
        // Do not auto-listen while a mic/model problem is showing, or we
        // would keep re-prompting the user for permission.
        final voiceBlocked = _voiceIssue != null &&
            _voiceIssue!.kind != VoiceIssueKind.ttsVoiceMissing;
        if (currentSettings.autoListenEnabled &&
            !voiceBlocked &&
            (state == DialogueState.collecting ||
                state == DialogueState.questioning ||
                state == DialogueState.guiding)) {
          startListening();
        }
        notifyListeners();
      };

      // 4. Initialize active speech recognizer. Failure here is not fatal:
      // typing and the quick-reply chips still work without voice.
      await recognizer.initialize();
      _setupRecognizerSubscriptions();
      await _checkVoiceReadiness();

      // 5. Start dialogue session with friendly welcome greeting
      startNewSession();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing DiagnosisViewModel: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupRecognizerSubscriptions() {
    _partialSub?.cancel();
    _finalSub?.cancel();

    _partialSub = recognizer.partialResults.listen((partial) {
      _livePartialText = partial;
      notifyListeners();
    });

    _finalSub = recognizer.finalResults.listen((finalText) {
      _livePartialText = '';
      if (_speechStartTime != null) {
        final latency =
            DateTime.now().difference(_speechStartTime!).inMilliseconds;
        settingsRepo.recordTimings(sttLatencyMs: latency);
      }
      processUserInput(finalText);
    });
  }

  /// Starts or restarts a clean diagnostic session.
  void startNewSession() {
    _messages.clear();
    _sessionStartTime = DateTime.now();
    _sessionInferenceMicros = 0;

    final response = _dialogueManager!.startSession();
    _addSystemMessage(response.spokenText,
        isSafetyAlert: response.isSafetyAlert);
    _speakIfEnabled(response.spokenText);
    notifyListeners();
  }

  /// Processes text or voice input through DialogueManager.
  Future<void> processUserInput(String input) async {
    final text = input.trim();
    if (text.isEmpty) return;

    // Add user message to transcript
    _messages.add(ChatMessage(text: text, isUser: true));
    notifyListeners();

    // Pause mic while inference & response happen
    if (recognizer.isListening) {
      await recognizer.stopListening();
    }

    final stopwatch = Stopwatch()..start();
    final response = _dialogueManager!.processUtterance(text);
    stopwatch.stop();

    _sessionInferenceMicros += stopwatch.elapsedMicroseconds;
    final inferenceMs = stopwatch.elapsedMilliseconds;
    await settingsRepo.recordTimings(inferenceMs: inferenceMs);

    // Add system response to transcript
    _addSystemMessage(
      response.spokenText,
      faultId: response.fault?.id,
      confidence: response.candidate?.cf,
      isSafetyAlert: response.isSafetyAlert,
    );

    // Speak response if voice output is enabled
    await _speakIfEnabled(response.spokenText);

    // If resolved or escalated, log session
    if (state == DialogueState.resolved || state == DialogueState.escalated) {
      _logCurrentSession(
          outcome: state == DialogueState.resolved ? 'resolved' : 'escalated');
    }

    notifyListeners();
  }

  void _addSystemMessage(
    String text, {
    String? faultId,
    double? confidence,
    bool isSafetyAlert = false,
  }) {
    _messages.add(
      ChatMessage(
        text: text,
        isUser: false,
        faultId: faultId,
        confidence: confidence,
        isSafetyAlert: isSafetyAlert,
      ),
    );
  }

  Future<void> _speakIfEnabled(String text) async {
    final settings = await settingsRepo.getSettings();
    if (settings.voiceOutputEnabled) {
      await tts.speak(text);
    }
  }

  /// Toggles microphone listening for push-to-talk.
  Future<void> toggleListening() async {
    if (recognizer.isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  Future<void> startListening() async {
    // Ask for the microphone the first time the user actually needs it.
    if (!await VoicePermissions.hasMicrophonePermission() &&
        !await VoicePermissions.requestMicrophonePermission()) {
      _setVoiceIssue(_micIssue);
      return;
    }
    if (!recognizer.isInitialized && !await recognizer.initialize()) {
      _setVoiceIssue(_modelIssue);
      return;
    }
    if (tts.isSpeaking) {
      await tts.stop();
    }
    _speechStartTime = DateTime.now();
    _livePartialText = '';
    try {
      await recognizer.startListening();
      // Listening worked, so clear any old mic/model banner.
      if (_voiceIssue?.kind != VoiceIssueKind.ttsVoiceMissing) {
        _voiceIssue = null;
      }
    } catch (e) {
      _setVoiceIssue(VoiceIssue(VoiceIssueKind.listenFailed,
          'Could not start listening ($e). You can type your problem instead.'));
    }
    notifyListeners();
  }

  static const _micIssue = VoiceIssue(
      VoiceIssueKind.micPermission,
      'Microphone permission is off. Tap "Fix" and allow the microphone, '
      'or type your problem below.');
  static const _modelIssue = VoiceIssue(
      VoiceIssueKind.modelMissing,
      'Speech model not found. Put vosk-model-small-en-us-0.15.zip in '
      'assets/models/ and rebuild, or switch engine in Settings.');
  static const _ttsIssue = VoiceIssue(
      VoiceIssueKind.ttsVoiceMissing,
      'Offline voice data is missing, so answers may not be spoken. Open '
      'Android Settings > Text-to-speech output and download English.');

  /// Checks voice readiness once at startup and picks the most important
  /// problem to show. The mic is only checked, not requested, here.
  Future<void> _checkVoiceReadiness() async {
    if (!recognizer.isInitialized) {
      _voiceIssue = _modelIssue;
    } else if (!await VoicePermissions.hasMicrophonePermission()) {
      _voiceIssue = _micIssue;
    } else if (!tts.isReady || !tts.isOfflineVoiceInstalled) {
      _voiceIssue = _ttsIssue;
    } else {
      _voiceIssue = null;
    }
  }

  void _setVoiceIssue(VoiceIssue issue) {
    _voiceIssue = issue;
    notifyListeners();
  }

  /// Hides the current voice banner until the next problem occurs.
  void dismissVoiceIssue() {
    _voiceIssue = null;
    notifyListeners();
  }

  /// Action for the banner's "Fix" button.
  Future<void> fixVoiceIssue() async {
    if (_voiceIssue?.kind == VoiceIssueKind.micPermission) {
      if (await VoicePermissions.isPermanentlyDenied()) {
        await VoicePermissions.openAppSettingsPage();
      } else if (await VoicePermissions.requestMicrophonePermission()) {
        await _checkVoiceReadiness();
        notifyListeners();
      }
    }
  }

  Future<void> stopListening() async {
    await recognizer.stopListening();
    _livePartialText = '';
    notifyListeners();
  }

  /// Quick reply shortcuts
  void answerYes() => processUserInput('yes');
  void answerNo() => processUserInput('no');
  void answerUnsure() => processUserInput('not sure');
  void nextStep() => processUserInput('next');
  void previousStep() => processUserInput('back');
  void repeatStep() => processUserInput('repeat');
  void explainWhy() => processUserInput('why');
  void confirmFixed() => processUserInput('fixed');
  void confirmDidNotWork() => processUserInput('didnt work');

  /// Swaps speech recognizer engine.
  Future<void> switchRecognizer(SpeechRecognizerService newRecognizer) async {
    await _services.setSpeechRecognizer(newRecognizer);
    await newRecognizer.initialize();
    _setupRecognizerSubscriptions();
    await _checkVoiceReadiness();
    notifyListeners();
  }

  Fault? getFaultById(String id) => _kb?.getFault(id);

  void _logCurrentSession({required String outcome}) {
    if (_dialogueManager == null) return;

    final knownIds = _dialogueManager!.workingMemory.knownSymptomIds;
    final questions = <SessionQuestionLog>[];

    for (final id in knownIds) {
      final symptom = _kb?.getSymptom(id);
      final isT = _dialogueManager!.workingMemory.isTrue(id);
      final isF = _dialogueManager!.workingMemory.isFalse(id);
      final ans = isT ? 'yes' : (isF ? 'no' : 'unsure');
      questions.add(
        SessionQuestionLog(
          symptomId: id,
          question: symptom?.question ?? id,
          answer: ans,
        ),
      );
    }

    final initialUtteranceMsg = _messages.firstWhere(
      (m) => m.isUser,
      orElse: () => ChatMessage(text: '', isUser: true),
    );

    final session = DiagnosticSessionLog(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: _sessionStartTime ?? DateTime.now(),
      initialUtterance: initialUtteranceMsg.text,
      assertedSymptoms: knownIds.toList(),
      questions: questions,
      diagnosedFaultId: currentFault?.id,
      diagnosedFaultName: currentFault?.name,
      confidence: currentCandidate?.cf,
      outcome: outcome,
      inferenceMs: (_sessionInferenceMicros / 1000).round(),
      totalDurationMs: DateTime.now()
          .difference(_sessionStartTime ?? DateTime.now())
          .inMilliseconds,
      excludedFaults: _dialogueManager!.excludedFaults.toList(),
    );

    logger.logSession(session);
  }

  @override
  void dispose() {
    _partialSub?.cancel();
    _finalSub?.cancel();
    super.dispose();
  }
}
