// Vosk-based offline speech-to-text recognizer running local Kaldi models.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'speech_recognizer_service.dart';

/// Primary offline speech recognizer powered by the bundled Vosk ASR engine.
class VoskSpeechRecognizer implements SpeechRecognizerService {
  /// Default path to bundled model asset in the application package.
  static const String defaultModelAsset =
      'assets/models/vosk-model-small-en-us-0.15.zip';

  /// Standard audio sample rate expected by the Vosk acoustic model.
  static const int sampleRate = 16000;

  /// Path to the model asset (configurable to allow accent testing models).
  final String modelAssetPath;

  final StreamController<String> _partialResultsController =
      StreamController<String>.broadcast();
  final StreamController<String> _finalResultsController =
      StreamController<String>.broadcast();

  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  StreamSubscription<String>? _resultSubscription;
  StreamSubscription<String>? _partialSubscription;

  bool _isInitialized = false;
  bool _isListening = false;
  String? _initError;

  /// Creates a Vosk recognizer with an optional custom model asset path.
  VoskSpeechRecognizer({this.modelAssetPath = defaultModelAsset});

  @override
  String get engineName => 'Vosk Offline ASR';

  @override
  bool get isOffline => true;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isListening => _isListening;

  /// Error message if initialization failed (e.g. model asset missing).
  String? get initError => _initError;

  @override
  Stream<String> get partialResults => _partialResultsController.stream;

  @override
  Stream<String> get finalResults => _finalResultsController.stream;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final modelLoader = ModelLoader();
      // Unpacks asset zip once into documents directory and caches the folder.
      final modelPath = await modelLoader.loadFromAssets(modelAssetPath);

      final vosk = VoskFlutterPlugin.instance();
      _model = await vosk.createModel(modelPath);
      _recognizer = await vosk.createRecognizer(
        model: _model!,
        sampleRate: sampleRate,
      );
      _speechService = await vosk.initSpeechService(_recognizer!);

      // Listen to native recognition result streams.
      _resultSubscription = _speechService!.onResult().listen((rawJson) {
        final text = parseResultJson(rawJson);
        if (text.isNotEmpty) {
          _finalResultsController.add(text);
        }
      });

      _partialSubscription = _speechService!.onPartial().listen((rawJson) {
        final partial = parsePartialJson(rawJson);
        if (partial.isNotEmpty) {
          _partialResultsController.add(partial);
        }
      });

      _isInitialized = true;
      _initError = null;
      return true;
    } catch (e) {
      _isInitialized = false;
      _initError = e.toString();
      debugPrint('VoskSpeechRecognizer initialization failed: $e');
      return false;
    }
  }

  @override
  Future<void> startListening() async {
    if (!_isInitialized || _speechService == null) {
      throw StateError('Cannot start listening: Vosk engine is not initialized.');
    }
    if (_isListening) return;

    try {
      await _speechService!.reset();
      await _speechService!.start();
      _isListening = true;
    } catch (e) {
      _isListening = false;
      debugPrint('Error starting Vosk listening: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening || _speechService == null) return;

    try {
      await _speechService!.stop();
      _isListening = false;
    } catch (e) {
      _isListening = false;
      debugPrint('Error stopping Vosk listening: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await stopListening();
    await _resultSubscription?.cancel();
    await _partialSubscription?.cancel();
    _resultSubscription = null;
    _partialSubscription = null;

    try {
      await _speechService?.dispose();
      await _recognizer?.dispose();
    } catch (e) {
      debugPrint('Error disposing Vosk recognizer: $e');
    }

    _speechService = null;
    _recognizer = null;
    _model = null;
    _isInitialized = false;

    await _partialResultsController.close();
    await _finalResultsController.close();
  }

  /// Extracts the transcribed text string from Vosk final result JSON.
  /// Example: '{"text": "paper jam in tray"}' -> 'paper jam in tray'.
  static String parseResultJson(String rawJson) {
    if (rawJson.trim().isEmpty) return '';
    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        final text = decoded['text'];
        if (text is String) return text.trim();
      }
    } catch (_) {
      // Return empty string on invalid json.
    }
    return '';
  }

  /// Extracts the intermediate transcribed text string from Vosk partial JSON.
  /// Example: '{"partial": "paper jam"}' -> 'paper jam'.
  static String parsePartialJson(String rawJson) {
    if (rawJson.trim().isEmpty) return '';
    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        final partial = decoded['partial'];
        if (partial is String) return partial.trim();
      }
    } catch (_) {
      // Return empty string on invalid json.
    }
    return '';
  }
}
