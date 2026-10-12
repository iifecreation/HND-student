// Unit tests for voice layer services, JSON parsers, and edge diagnostic contracts.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_doc/app/service_locator.dart';
import 'package:printer_doc/voice/edge_status.dart';
import 'package:printer_doc/voice/speech_recognizer_service.dart';
import 'package:printer_doc/voice/vosk_speech_recognizer.dart';

/// Test mock implementation of SpeechRecognizerService for pure-Dart test harnesses.
class MockSpeechRecognizer implements SpeechRecognizerService {
  final StreamController<String> _partialController =
      StreamController<String>.broadcast();
  final StreamController<String> _finalController =
      StreamController<String>.broadcast();

  bool _initialized = false;
  bool _listening = false;

  @override
  String get engineName => 'Mock STT Engine';

  @override
  bool get isOffline => true;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isListening => _listening;

  @override
  Stream<String> get partialResults => _partialController.stream;

  @override
  Stream<String> get finalResults => _finalController.stream;

  @override
  Future<bool> initialize() async {
    _initialized = true;
    return true;
  }

  @override
  Future<void> startListening() async {
    _listening = true;
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }

  void emitPartial(String text) => _partialController.add(text);
  void emitFinal(String text) => _finalController.add(text);

  @override
  Future<void> dispose() async {
    _listening = false;
    _initialized = false;
    await _partialController.close();
    await _finalController.close();
  }
}

void main() {
  group('VoskSpeechRecognizer JSON Parsing', () {
    test('parses normal result text correctly', () {
      const json = '{"text": "paper jam in tray"}';
      expect(VoskSpeechRecognizer.parseResultJson(json), 'paper jam in tray');
    });

    test('parses empty or whitespace result as empty string', () {
      expect(VoskSpeechRecognizer.parseResultJson('{"text": ""}'), '');
      expect(VoskSpeechRecognizer.parseResultJson('{"text": "   "}'), '');
    });

    test('parses result with word timings and tokens', () {
      const json =
          '{"result": [{"conf": 1.0, "end": 1.2, "start": 0.5, "word": "printer"}], "text": "printer offline"}';
      expect(VoskSpeechRecognizer.parseResultJson(json), 'printer offline');
    });

    test('handles malformed JSON gracefully', () {
      expect(VoskSpeechRecognizer.parseResultJson('{invalid: json}'), '');
      expect(VoskSpeechRecognizer.parseResultJson(''), '');
      expect(VoskSpeechRecognizer.parseResultJson('   '), '');
    });

    test('parses partial results correctly', () {
      const json = '{"partial": "printer is"}';
      expect(VoskSpeechRecognizer.parsePartialJson(json), 'printer is');
      expect(VoskSpeechRecognizer.parsePartialJson('{"partial": ""}'), '');
      expect(VoskSpeechRecognizer.parsePartialJson('not valid'), '');
    });
  });

  group('Mock SpeechRecognizer Contract', () {
    late MockSpeechRecognizer recognizer;

    setUp(() {
      recognizer = MockSpeechRecognizer();
    });

    tearDown(() async {
      await recognizer.dispose();
    });

    test('tracks initialized and listening state', () async {
      expect(recognizer.isInitialized, isFalse);
      expect(recognizer.isListening, isFalse);

      await recognizer.initialize();
      expect(recognizer.isInitialized, isTrue);

      await recognizer.startListening();
      expect(recognizer.isListening, isTrue);

      await recognizer.stopListening();
      expect(recognizer.isListening, isFalse);
    });

    test('streams partial and final results', () async {
      await recognizer.initialize();

      final partials = <String>[];
      final finals = <String>[];

      final subP = recognizer.partialResults.listen(partials.add);
      final subF = recognizer.finalResults.listen(finals.add);

      recognizer.emitPartial('paper');
      recognizer.emitPartial('paper jam');
      recognizer.emitFinal('paper jam in tray');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(partials, equals(['paper', 'paper jam']));
      expect(finals, equals(['paper jam in tray']));

      await subP.cancel();
      await subF.cancel();
    });
  });

  group('EdgeStatus Diagnostic Model', () {
    test('isFullyReady returns true only when all edge criteria are satisfied', () {
      const ready = EdgeStatus(
        modelLoaded: true,
        modelPath: 'assets/models/vosk.zip',
        micPermissionGranted: true,
        ttsReady: true,
        offlineVoiceInstalled: true,
        internetPermissionPresent: false,
        activeSttEngine: 'Vosk Offline ASR',
      );
      expect(ready.isFullyReady, isTrue);

      const noModel = EdgeStatus(
        modelLoaded: false,
        modelPath: 'assets/models/vosk.zip',
        micPermissionGranted: true,
        ttsReady: true,
        offlineVoiceInstalled: true,
        internetPermissionPresent: false,
        activeSttEngine: 'Vosk Offline ASR',
      );
      expect(noModel.isFullyReady, isFalse);

      const noMic = EdgeStatus(
        modelLoaded: true,
        modelPath: 'assets/models/vosk.zip',
        micPermissionGranted: false,
        ttsReady: true,
        offlineVoiceInstalled: true,
        internetPermissionPresent: false,
        activeSttEngine: 'Vosk Offline ASR',
      );
      expect(noMic.isFullyReady, isFalse);

      // Hard NFR1 check: if internet permission was present, it must fail readiness
      const internetLeaked = EdgeStatus(
        modelLoaded: true,
        modelPath: 'assets/models/vosk.zip',
        micPermissionGranted: true,
        ttsReady: true,
        offlineVoiceInstalled: true,
        internetPermissionPresent: true,
        activeSttEngine: 'Vosk Offline ASR',
      );
      expect(internetLeaked.isFullyReady, isFalse);
    });
  });

  group('ServiceLocator', () {
    test('provides and switches speech recognizers', () async {
      final locator = ServiceLocator();
      expect(locator.speechRecognizer, isNotNull);

      final customMock = MockSpeechRecognizer();
      await locator.setSpeechRecognizer(customMock);
      expect(locator.speechRecognizer, equals(customMock));
      expect(locator.speechRecognizer.engineName, equals('Mock STT Engine'));
    });
  });
}
