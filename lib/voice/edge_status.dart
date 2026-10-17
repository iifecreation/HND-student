// Data model and diagnostic helper for edge self-check and offline status.

import 'package:flutter/services.dart';
import 'permissions.dart';
import 'speech_recognizer_service.dart';
import 'tts_service.dart';

/// Data class holding results of the edge status and offline compliance check.
class EdgeStatus {
  /// Whether the Vosk acoustic model is loaded in memory and ready.
  final bool modelLoaded;

  /// Path to the current Vosk model file or asset.
  final String modelPath;

  /// Whether microphone permission has been granted by the user.
  final bool micPermissionGranted;

  /// Whether TTS engine initialized successfully.
  final bool ttsReady;

  /// Whether offline TTS voice data is installed on the device.
  final bool offlineVoiceInstalled;

  /// Whether INTERNET permission is present (must be false for offline compliance).
  final bool internetPermissionPresent;

  /// Name of the active speech-to-text engine.
  final String activeSttEngine;

  /// Optional detail or troubleshooting message for the user.
  final String? statusMessage;

  const EdgeStatus({
    required this.modelLoaded,
    required this.modelPath,
    required this.micPermissionGranted,
    required this.ttsReady,
    required this.offlineVoiceInstalled,
    required this.internetPermissionPresent,
    required this.activeSttEngine,
    this.statusMessage,
  });

  /// Evaluates overall readiness for offline voice diagnosis.
  bool get isFullyReady =>
      modelLoaded &&
      micPermissionGranted &&
      ttsReady &&
      !internetPermissionPresent;

  /// Diagnostic factory running self-checks across microphone, TTS, and STT.
  static Future<EdgeStatus> runCheck({
    required SpeechRecognizerService recognizer,
    required TtsService tts,
    required String modelPath,
  }) async {
    final micGranted = await VoicePermissions.hasMicrophonePermission();
    final ttsReady = tts.isReady;
    final offlineVoice = tts.isOfflineVoiceInstalled;
    final modelReady = recognizer.isInitialized;

    // Hard rule NFR1: the release APK must not declare INTERNET.
    // We ask Android which permissions the installed APK declares rather
    // than assuming. Debug builds legitimately include INTERNET (Flutter needs
    // it for hot reload), so this only shows "absent" on a release build.
    final internetPresent = await _declaresInternet();

    String? message;
    if (!micGranted) {
      message = 'Microphone permission required for voice diagnosis.';
    } else if (!modelReady) {
      message =
          'Vosk model not loaded. Download vosk-model-small-en-us-0.15.zip into assets/models/.';
    } else if (!offlineVoice) {
      message =
          'Offline TTS voice missing. Install English voice in Android Settings -> Text-to-speech.';
    }

    return EdgeStatus(
      modelLoaded: modelReady,
      modelPath: modelPath,
      micPermissionGranted: micGranted,
      ttsReady: ttsReady,
      offlineVoiceInstalled: offlineVoice,
      internetPermissionPresent: internetPresent,
      activeSttEngine: recognizer.engineName,
      statusMessage: message,
    );
  }

  /// Channel implemented in android/.../MainActivity.kt.
  static const MethodChannel _edgeChannel = MethodChannel('printer_doc/edge');

  /// Returns true if the installed APK declares android.permission.INTERNET.
  /// If the check cannot run (for example in unit tests with no Android
  /// side), it returns true so we never wrongly claim the app is offline.
  static Future<bool> _declaresInternet() async {
    try {
      final perms =
          await _edgeChannel.invokeListMethod<String>('declaredPermissions');
      return perms == null || perms.contains('android.permission.INTERNET');
    } catch (_) {
      return true;
    }
  }
}
