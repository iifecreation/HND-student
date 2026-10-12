// Persists user preferences and edge diagnostic settings using shared_preferences.

import 'package:shared_preferences/shared_preferences.dart';

/// Immutable model representing all user-configurable preferences and edge benchmarks.
class UserSettings {
  final double speechRate;
  final bool voiceOutputEnabled;
  final bool autoListenEnabled;
  final String sttEngine; // 'vosk' or 'device'
  final String voskModelPath;
  final int lastInferenceMs;
  final int lastSttLatencyMs;

  const UserSettings({
    this.speechRate = 0.45,
    this.voiceOutputEnabled = true,
    this.autoListenEnabled = false,
    this.sttEngine = 'vosk',
    this.voskModelPath = 'assets/models/vosk-model-small-en-us-0.15.zip',
    this.lastInferenceMs = 0,
    this.lastSttLatencyMs = 0,
  });

  UserSettings copyWith({
    double? speechRate,
    bool? voiceOutputEnabled,
    bool? autoListenEnabled,
    String? sttEngine,
    String? voskModelPath,
    int? lastInferenceMs,
    int? lastSttLatencyMs,
  }) {
    return UserSettings(
      speechRate: speechRate ?? this.speechRate,
      voiceOutputEnabled: voiceOutputEnabled ?? this.voiceOutputEnabled,
      autoListenEnabled: autoListenEnabled ?? this.autoListenEnabled,
      sttEngine: sttEngine ?? this.sttEngine,
      voskModelPath: voskModelPath ?? this.voskModelPath,
      lastInferenceMs: lastInferenceMs ?? this.lastInferenceMs,
      lastSttLatencyMs: lastSttLatencyMs ?? this.lastSttLatencyMs,
    );
  }
}

/// Repository responsible for loading and saving settings via SharedPreferences (FR13).
class SettingsRepository {
  static const String keySpeechRate = 'printer_doc_speech_rate';
  static const String keyVoiceOutput = 'printer_doc_voice_output';
  static const String keyAutoListen = 'printer_doc_auto_listen';
  static const String keySttEngine = 'printer_doc_stt_engine';
  static const String keyVoskModelPath = 'printer_doc_vosk_model_path';
  static const String keyLastInferenceMs = 'printer_doc_last_inference_ms';
  static const String keyLastSttLatencyMs = 'printer_doc_last_stt_latency_ms';

  final SharedPreferences? _injectedPrefs;

  /// Creates a repository, optionally accepting injected preferences for testing.
  SettingsRepository({SharedPreferences? preferences})
      : _injectedPrefs = preferences;

  Future<SharedPreferences> _getPrefs() async {
    return _injectedPrefs ?? await SharedPreferences.getInstance();
  }

  /// Loads current user settings, applying sensible edge defaults where unset.
  Future<UserSettings> getSettings() async {
    final prefs = await _getPrefs();
    return UserSettings(
      speechRate: prefs.getDouble(keySpeechRate) ?? 0.45,
      voiceOutputEnabled: prefs.getBool(keyVoiceOutput) ?? true,
      autoListenEnabled: prefs.getBool(keyAutoListen) ?? false,
      sttEngine: prefs.getString(keySttEngine) ?? 'vosk',
      voskModelPath: prefs.getString(keyVoskModelPath) ??
          'assets/models/vosk-model-small-en-us-0.15.zip',
      lastInferenceMs: prefs.getInt(keyLastInferenceMs) ?? 0,
      lastSttLatencyMs: prefs.getInt(keyLastSttLatencyMs) ?? 0,
    );
  }

  /// Updates speech pacing rate (0.1 to 1.0).
  Future<void> setSpeechRate(double rate) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(keySpeechRate, rate.clamp(0.1, 1.0));
  }

  /// Enables or disables spoken audio replies.
  Future<void> setVoiceOutputEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(keyVoiceOutput, enabled);
  }

  /// Toggles automatic microphone activation after system speaks.
  Future<void> setAutoListenEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(keyAutoListen, enabled);
  }

  /// Changes the active STT engine ('vosk' or 'device').
  Future<void> setSttEngine(String engine) async {
    final prefs = await _getPrefs();
    await prefs.setString(keySttEngine, engine);
  }

  /// Sets custom Vosk model asset path (useful for accent comparison models).
  Future<void> setVoskModelPath(String path) async {
    final prefs = await _getPrefs();
    await prefs.setString(keyVoskModelPath, path);
  }

  /// Records recent inference and speech recognition latency for edge status card.
  Future<void> recordTimings({int? inferenceMs, int? sttLatencyMs}) async {
    final prefs = await _getPrefs();
    if (inferenceMs != null) {
      await prefs.setInt(keyLastInferenceMs, inferenceMs);
    }
    if (sttLatencyMs != null) {
      await prefs.setInt(keyLastSttLatencyMs, sttLatencyMs);
    }
  }

  /// Resets all preferences back to factory defaults.
  Future<void> resetToDefaults() async {
    final prefs = await _getPrefs();
    await prefs.remove(keySpeechRate);
    await prefs.remove(keyVoiceOutput);
    await prefs.remove(keyAutoListen);
    await prefs.remove(keySttEngine);
    await prefs.remove(keyVoskModelPath);
    await prefs.remove(keyLastInferenceMs);
    await prefs.remove(keyLastSttLatencyMs);
  }
}
