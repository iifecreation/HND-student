// Entry point for the PrinterDoc voice-controlled offline expert system application.

import 'dart:async';
import 'package:flutter/material.dart';
import 'app/service_locator.dart';
import 'voice/device_speech_recognizer.dart';
import 'voice/edge_status.dart';
import 'voice/permissions.dart';
import 'voice/speech_recognizer_service.dart';
import 'voice/vosk_speech_recognizer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrinterDocApp());
}

/// Root application widget configuring themes and initial routes.
class PrinterDocApp extends StatelessWidget {
  const PrinterDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrinterDoc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006699),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006699),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const VoiceDebugScreen(),
    );
  }
}

/// Voice service diagnostic and edge self-check screen for Phase 5 verification.
class VoiceDebugScreen extends StatefulWidget {
  const VoiceDebugScreen({super.key});

  @override
  State<VoiceDebugScreen> createState() => _VoiceDebugScreenState();
}

class _VoiceDebugScreenState extends State<VoiceDebugScreen> {
  final ServiceLocator _services = ServiceLocator();
  EdgeStatus? _edgeStatus;
  bool _isLoading = true;

  String _partialText = '';
  String _finalText = '';
  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _finalSub;

  final TextEditingController _ttsInputController =
      TextEditingController(text: 'PrinterDoc offline voice test successful.');

  @override
  void initState() {
    super.initState();
    _initVoiceServices();
  }

  Future<void> _initVoiceServices() async {
    setState(() => _isLoading = true);

    // Initialize TTS
    await _services.tts.initialize();

    // Check microphone permission
    final hasMic = await VoicePermissions.hasMicrophonePermission();
    if (!hasMic) {
      await VoicePermissions.requestMicrophonePermission();
    }

    // Try initializing primary recognizer (Vosk)
    final recognizer = _services.speechRecognizer;
    await recognizer.initialize();

    _setupStreamListeners(recognizer);
    await _refreshStatus();

    setState(() => _isLoading = false);
  }

  void _setupStreamListeners(SpeechRecognizerService recognizer) {
    _partialSub?.cancel();
    _finalSub?.cancel();

    _partialSub = recognizer.partialResults.listen((text) {
      if (mounted) setState(() => _partialText = text);
    });

    _finalSub = recognizer.finalResults.listen((text) {
      if (mounted) {
        setState(() {
          _finalText = text;
          _partialText = '';
        });
      }
    });
  }

  Future<void> _refreshStatus() async {
    final status = await EdgeStatus.runCheck(
      recognizer: _services.speechRecognizer,
      tts: _services.tts,
      modelPath: VoskSpeechRecognizer.defaultModelAsset,
    );
    if (mounted) {
      setState(() => _edgeStatus = status);
    }
  }

  Future<void> _toggleListening() async {
    final recognizer = _services.speechRecognizer;
    if (recognizer.isListening) {
      await recognizer.stopListening();
    } else {
      if (!recognizer.isInitialized) {
        final ok = await recognizer.initialize();
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Recognizer not initialized. Check model in assets/models/.'),
              ),
            );
          }
          return;
        }
      }
      try {
        await recognizer.startListening();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start listening: $e')),
          );
        }
      }
    }
    setState(() {});
  }

  Future<void> _switchEngine() async {
    final current = _services.speechRecognizer;
    if (current is VoskSpeechRecognizer) {
      final fallback = DeviceSpeechRecognizer();
      await fallback.initialize();
      await _services.setSpeechRecognizer(fallback);
      _setupStreamListeners(fallback);
    } else {
      final vosk = VoskSpeechRecognizer();
      await vosk.initialize();
      await _services.setSpeechRecognizer(vosk);
      _setupStreamListeners(vosk);
    }
    await _refreshStatus();
  }

  Future<void> _testTts() async {
    final text = _ttsInputController.text.trim();
    if (text.isNotEmpty) {
      await _services.tts.speak(text);
    }
  }

  @override
  void dispose() {
    _partialSub?.cancel();
    _finalSub?.cancel();
    _ttsInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recognizer = _services.speechRecognizer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PrinterDoc Edge Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildEdgeStatusCard(theme),
                const SizedBox(height: 16),
                _buildSttCard(theme, recognizer),
                const SizedBox(height: 16),
                _buildTtsCard(theme),
              ],
            ),
    );
  }

  Widget _buildEdgeStatusCard(ThemeData theme) {
    final status = _edgeStatus;
    if (status == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.isFullyReady ? Icons.check_circle : Icons.info,
                  color: status.isFullyReady ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edge Self-Check & Offline Status',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _statusRow('Active STT Engine', status.activeSttEngine),
            _statusRow(
              'Vosk Acoustic Model',
              status.modelLoaded ? 'Loaded' : 'Not Found / Unloaded',
              isOk: status.modelLoaded,
            ),
            _statusRow(
              'Microphone Permission',
              status.micPermissionGranted ? 'Granted' : 'Denied',
              isOk: status.micPermissionGranted,
            ),
            _statusRow(
              'TTS Ready',
              status.ttsReady ? 'Ready' : 'Not Ready',
              isOk: status.ttsReady,
            ),
            _statusRow(
              'Offline Voice Data',
              status.offlineVoiceInstalled ? 'Installed' : 'Needs Check',
              isOk: status.offlineVoiceInstalled,
            ),
            _statusRow(
              'INTERNET Permission',
              status.internetPermissionPresent ? 'Present (Fail)' : 'Absent (100% Offline)',
              isOk: !status.internetPermissionPresent,
            ),
            if (status.statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Text(
                  status.statusMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value, {bool? isOk}) {
    Color? textColor;
    if (isOk != null) {
      textColor = isOk ? Colors.green.shade700 : Colors.red.shade700;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSttCard(ThemeData theme, SpeechRecognizerService recognizer) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Voice Input (STT)',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Switch Engine'),
                  onPressed: _switchEngine,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      recognizer.isListening ? Colors.red : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: Icon(
                    recognizer.isListening ? Icons.mic_off : Icons.mic),
                label: Text(
                  recognizer.isListening
                      ? 'Stop Listening'
                      : 'Start Push-to-Talk',
                ),
                onPressed: _toggleListening,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Partial Transcription (Live):',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(top: 4, bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _partialText.isEmpty ? '(speaking preview appears here...)' : _partialText,
                style: TextStyle(
                  fontStyle:
                      _partialText.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            const Text(
              'Final Recognized Utterance:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _finalText.isEmpty ? '(final recognized text appears here)' : _finalText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontStyle:
                      _finalText.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTtsCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Output (TTS)',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ttsInputController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Text to speak',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Speak Text'),
                  onPressed: _testTts,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  onPressed: () => _services.tts.stop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
