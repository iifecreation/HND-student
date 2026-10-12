// Abstract interface defining offline speech-to-text recognition contracts and event streams.

import 'dart:async';

/// Common interface for speech-to-text recognizers.
///
/// Decouples the UI and dialogue manager from specific STT implementations
/// (such as Vosk or on-device SpeechToText).
abstract class SpeechRecognizerService {
  /// Name of this speech recognition engine (e.g. 'Vosk' or 'Device STT').
  String get engineName;

  /// Whether this recognizer operates fully offline without sending audio to the cloud.
  bool get isOffline;

  /// Whether the engine has been successfully initialized and is ready.
  bool get isInitialized;

  /// Whether the recognizer is actively listening to the microphone.
  bool get isListening;

  /// Stream of partial, intermediate transcriptions while user is speaking.
  Stream<String> get partialResults;

  /// Stream of completed, final transcriptions once the user pauses or stops.
  Stream<String> get finalResults;

  /// Initializes models, engines, and audio pipelines.
  /// Returns true if initialization succeeded, false otherwise.
  Future<bool> initialize();

  /// Begins listening for voice input.
  Future<void> startListening();

  /// Stops listening and commits final transcription.
  Future<void> stopListening();

  /// Releases audio resources, recognizers, and stream controllers.
  Future<void> dispose();
}
