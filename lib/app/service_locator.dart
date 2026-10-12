// Central service locator providing singleton access to core, voice, and data services.

import '../data/session_logger.dart';
import '../data/settings_repository.dart';
import '../knowledge/kb_loader.dart';
import '../voice/speech_recognizer_service.dart';
import '../voice/tts_service.dart';
import '../voice/vosk_speech_recognizer.dart';

/// Simple service locator for sharing app-wide singletons without third-party DI bloat.
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  KnowledgeBase? kb;
  SpeechRecognizerService? _recognizer;
  TtsService? _tts;
  SessionLogger? _sessionLogger;
  SettingsRepository? _settingsRepository;

  /// Returns the active speech recognizer service (defaults to Vosk).
  SpeechRecognizerService get speechRecognizer =>
      _recognizer ??= VoskSpeechRecognizer();

  /// Returns the text-to-speech service.
  TtsService get tts => _tts ??= TtsService();

  /// Returns the local diagnostic session logger.
  SessionLogger get sessionLogger => _sessionLogger ??= SessionLogger();

  /// Returns the user settings and edge preferences repository.
  SettingsRepository get settingsRepository =>
      _settingsRepository ??= SettingsRepository();

  /// Switches active speech recognizer (e.g. between Vosk and on-device fallback).
  Future<void> setSpeechRecognizer(SpeechRecognizerService recognizer) async {
    await _recognizer?.dispose();
    _recognizer = recognizer;
  }

  /// Sets active knowledge base.
  void setKnowledgeBase(KnowledgeBase knowledgeBase) {
    kb = knowledgeBase;
  }
}
