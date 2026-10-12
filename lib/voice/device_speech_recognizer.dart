// Fallback speech-to-text recognizer using Android system on-device speech recognition.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'speech_recognizer_service.dart';

/// Fallback speech recognizer using Android's native SpeechRecognizer service in on-device mode.
class DeviceSpeechRecognizer implements SpeechRecognizerService {
  final SpeechToText _speechToText;
  final StreamController<String> _partialResultsController =
      StreamController<String>.broadcast();
  final StreamController<String> _finalResultsController =
      StreamController<String>.broadcast();

  bool _isInitialized = false;
  bool _isListening = false;
  String? _initError;

  /// Creates a DeviceSpeechRecognizer with an optional injected SpeechToText instance.
  DeviceSpeechRecognizer({SpeechToText? speechToText})
      : _speechToText = speechToText ?? SpeechToText();

  @override
  String get engineName => 'Device On-Device STT';

  @override
  bool get isOffline => true;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isListening => _isListening;

  /// Error message if initialization or speech engine availability failed.
  String? get initError => _initError;

  @override
  Stream<String> get partialResults => _partialResultsController.stream;

  @override
  Stream<String> get finalResults => _finalResultsController.stream;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final available = await _speechToText.initialize(
        onError: (errorNotification) {
          debugPrint('Device STT Error: ${errorNotification.errorMsg}');
        },
        onStatus: (status) {
          if (status == SpeechToText.notListeningStatus ||
              status == SpeechToText.doneStatus) {
            _isListening = false;
          }
        },
      );

      _isInitialized = available;
      if (!available) {
        _initError =
            'Device speech recognition is unavailable or requires offline voice package.';
      } else {
        _initError = null;
      }
      return available;
    } catch (e) {
      _isInitialized = false;
      _initError = e.toString();
      debugPrint('DeviceSpeechRecognizer initialize failed: $e');
      return false;
    }
  }

  @override
  Future<void> startListening() async {
    if (!_isInitialized) {
      throw StateError(
          'Cannot start listening: DeviceSpeechRecognizer is not initialized.');
    }
    if (_isListening) return;

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords.trim();
          if (result.finalResult) {
            if (words.isNotEmpty) {
              _finalResultsController.add(words);
            }
          } else {
            if (words.isNotEmpty) {
              _partialResultsController.add(words);
            }
          }
        },
        listenOptions: SpeechListenOptions(
          onDevice: true, // Guarantees speech audio does not leave the phone
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
      );
      _isListening = true;
    } catch (e) {
      _isListening = false;
      debugPrint('DeviceSpeechRecognizer startListening failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
    } catch (e) {
      _isListening = false;
      debugPrint('DeviceSpeechRecognizer stopListening failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await stopListening();
    _isInitialized = false;
    await _partialResultsController.close();
    await _finalResultsController.close();
  }
}
