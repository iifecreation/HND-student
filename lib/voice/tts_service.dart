// Local text-to-speech service using flutter_tts with offline voice check.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service managing offline text-to-speech synthesis with awaitable speak completion.
class TtsService {
  final FlutterTts _flutterTts;

  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isOfflineVoiceInstalled = true;
  double _speechRate = 0.45;
  String _language = 'en-US';

  /// Callbacks for half-duplex voice coordination (e.g. pausing mic).
  VoidCallback? onSpeechStarted;
  VoidCallback? onSpeechCompleted;

  /// Creates a TtsService with an optional injected FlutterTts instance.
  TtsService({FlutterTts? flutterTts}) : _flutterTts = flutterTts ?? FlutterTts();

  /// Whether TTS engine is initialized and ready to speak.
  bool get isReady => _isInitialized;

  /// Whether TTS is actively speaking audio right now.
  bool get isSpeaking => _isSpeaking;

  /// Current speech rate (default 0.45 for clear instructional pacing).
  double get speechRate => _speechRate;

  /// Whether the target language pack is installed locally on the device.
  bool get isOfflineVoiceInstalled => _isOfflineVoiceInstalled;

  /// Configured TTS language code.
  String get language => _language;

  /// Initializes the TTS engine with recommended edge settings.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      await _flutterTts.setLanguage(_language);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Ensures Future returned by speak() completes only when utterance finishes.
      await _flutterTts.awaitSpeakCompletion(true);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        onSpeechStarted?.call();
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeechCompleted?.call();
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        onSpeechCompleted?.call();
      });

      _flutterTts.setErrorHandler((dynamic message) {
        _isSpeaking = false;
        debugPrint('TtsService error: $message');
        onSpeechCompleted?.call();
      });

      // Verify whether the offline language pack is present on Android.
      try {
        final dynamic installed = await _flutterTts.isLanguageInstalled(_language);
        if (installed is bool) {
          _isOfflineVoiceInstalled = installed;
        } else if (installed is int) {
          // Android TextToSpeech.LANG_AVAILABLE is 0, LANG_COUNTRY_AVAILABLE is 1
          _isOfflineVoiceInstalled = installed >= 0;
        }
      } catch (e) {
        debugPrint('Warning: unable to query offline voice status: $e');
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      debugPrint('TtsService initialize failed: $e');
      return false;
    }
  }

  /// Speaks the given text and awaits its completion.
  Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    try {
      _isSpeaking = true;
      await _flutterTts.speak(clean);
    } catch (e) {
      _isSpeaking = false;
      debugPrint('TtsService speak failed: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  /// Stops current speech output immediately.
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      onSpeechCompleted?.call();
    } catch (e) {
      debugPrint('TtsService stop failed: $e');
    }
  }

  /// Sets speech rate (0.1 to 1.0; 0.45 recommended for clarity).
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    if (_isInitialized) {
      await _flutterTts.setSpeechRate(_speechRate);
    }
  }

  /// Sets TTS language code (e.g. 'en-US' or 'en-GB').
  Future<void> setLanguage(String lang) async {
    _language = lang;
    if (_isInitialized) {
      await _flutterTts.setLanguage(_language);
    }
  }

  /// Releases TTS native resources.
  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
  }
}
