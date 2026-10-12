// Settings and edge diagnostics screen for configuring speech pacing, engines, and offline status.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/service_locator.dart';
import '../../data/settings_repository.dart';
import '../../voice/device_speech_recognizer.dart';
import '../../voice/edge_status.dart';
import '../../voice/permissions.dart';
import '../../voice/vosk_speech_recognizer.dart';
import '../viewmodels/diagnosis_viewmodel.dart';

/// Screen managing edge voice parameters, acoustic model selection, and edge status auditing.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ServiceLocator _services = ServiceLocator();
  UserSettings? _settings;
  EdgeStatus? _edgeStatus;
  bool _isLoading = true;

  final TextEditingController _modelPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettingsAndStatus();
  }

  Future<void> _loadSettingsAndStatus() async {
    setState(() => _isLoading = true);
    final settings = await _services.settingsRepository.getSettings();
    _modelPathController.text = settings.voskModelPath;

    final status = await EdgeStatus.runCheck(
      recognizer: _services.speechRecognizer,
      tts: _services.tts,
      modelPath: settings.voskModelPath,
    );

    if (mounted) {
      setState(() {
        _settings = settings;
        _edgeStatus = status;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSpeechRate(double rate) async {
    await _services.settingsRepository.setSpeechRate(rate);
    await _services.tts.setSpeechRate(rate);
    _loadSettingsAndStatus();
  }

  Future<void> _toggleVoiceOutput(bool enabled) async {
    await _services.settingsRepository.setVoiceOutputEnabled(enabled);
    _loadSettingsAndStatus();
  }

  Future<void> _toggleAutoListen(bool enabled) async {
    await _services.settingsRepository.setAutoListenEnabled(enabled);
    _loadSettingsAndStatus();
  }

  Future<void> _changeSttEngine(String engine) async {
    final vm = context.read<DiagnosisViewModel>();
    await _services.settingsRepository.setSttEngine(engine);

    if (engine == 'device') {
      await vm.switchRecognizer(DeviceSpeechRecognizer());
    } else {
      await vm.switchRecognizer(VoskSpeechRecognizer(
        modelAssetPath: _settings?.voskModelPath ??
            VoskSpeechRecognizer.defaultModelAsset,
      ));
    }
    _loadSettingsAndStatus();
  }

  Future<void> _saveModelPath() async {
    final path = _modelPathController.text.trim();
    if (path.isNotEmpty) {
      final vm = context.read<DiagnosisViewModel>();
      await _services.settingsRepository.setVoskModelPath(path);
      await vm.switchRecognizer(VoskSpeechRecognizer(modelAssetPath: path));
      _loadSettingsAndStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vosk model path set to "$path"')),
        );
      }
    }
  }

  Future<void> _requestMicPermission() async {
    await VoicePermissions.requestMicrophonePermission();
    _loadSettingsAndStatus();
  }

  Future<void> _resetDefaults() async {
    final vm = context.read<DiagnosisViewModel>();
    await _services.settingsRepository.resetToDefaults();
    await vm.switchRecognizer(VoskSpeechRecognizer());
    _loadSettingsAndStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings reset to edge defaults.')),
      );
    }
  }

  @override
  void dispose() {
    _modelPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = _settings;
    final status = _edgeStatus;

    if (_isLoading || settings == null || status == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings & Edge Status')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Edge Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Defaults',
            onPressed: _resetDefaults,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Edge Status Self-Check Card
          _buildEdgeStatusCard(status, settings, theme),
          const SizedBox(height: 16),

          // Speech Output Preferences Card
          _buildTtsSettingsCard(settings, theme),
          const SizedBox(height: 16),

          // Speech Input Preferences Card
          _buildSttSettingsCard(settings, theme),
          const SizedBox(height: 16),

          // Acoustic Model Path (Accent Evaluation Support)
          _buildModelPathCard(theme),
        ],
      ),
    );
  }

  Widget _buildEdgeStatusCard(
      EdgeStatus status, UserSettings settings, ThemeData theme) {
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
                  status.isFullyReady ? Icons.check_circle : Icons.warning_amber,
                  color: status.isFullyReady ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edge Self-Check & Offline Audit',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _statusRow('Active STT Engine', status.activeSttEngine),
            _statusRow(
              'Acoustic Model Loaded',
              status.modelLoaded ? 'Yes (Edge RAM)' : 'No / Asset Missing',
              isOk: status.modelLoaded,
            ),
            _statusRow(
              'Microphone Permission',
              status.micPermissionGranted ? 'Granted' : 'Denied',
              isOk: status.micPermissionGranted,
              trailing: !status.micPermissionGranted
                  ? TextButton(
                      onPressed: _requestMicPermission,
                      child: const Text('Grant'),
                    )
                  : null,
            ),
            _statusRow(
              'TTS Engine Ready',
              status.ttsReady ? 'Yes' : 'No',
              isOk: status.ttsReady,
            ),
            _statusRow(
              'Offline Voice Pack',
              status.offlineVoiceInstalled ? 'Installed' : 'Needs Check',
              isOk: status.offlineVoiceInstalled,
            ),
            _statusRow(
              'INTERNET Permission',
              status.internetPermissionPresent ? 'Present (Violation)' : 'Absent (100% Offline)',
              isOk: !status.internetPermissionPresent,
            ),
            const Divider(),
            _statusRow(
              'Last STT Latency',
              settings.lastSttLatencyMs > 0
                  ? '${settings.lastSttLatencyMs} ms'
                  : 'N/A',
            ),
            _statusRow(
              'Last Inference Time',
              settings.lastInferenceMs > 0
                  ? '${settings.lastInferenceMs} ms'
                  : 'N/A',
            ),
            if (status.statusMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.statusMessage!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTtsSettingsCard(UserSettings settings, ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Speech Output (TTS)',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Spoken Responses'),
              subtitle: const Text('Speak diagnosis and instructions aloud'),
              value: settings.voiceOutputEnabled,
              onChanged: _toggleVoiceOutput,
            ),
            const SizedBox(height: 8),
            Text(
              'Speech Pacing Rate: ${settings.speechRate.toStringAsFixed(2)}x',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Slider(
              value: settings.speechRate,
              min: 0.2,
              max: 0.8,
              divisions: 12,
              label: '${settings.speechRate.toStringAsFixed(2)}x',
              onChanged: (val) => _saveSpeechRate(val),
            ),
            const Text(
              '0.45x is recommended for clear technician instructional pacing.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSttSettingsCard(UserSettings settings, ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Speech Recognition (STT)',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Listen Mode'),
              subtitle: const Text(
                'Automatically open microphone after system asks a question (half-duplex)',
              ),
              value: settings.autoListenEnabled,
              onChanged: _toggleAutoListen,
            ),
            const SizedBox(height: 8),
            const Text(
              'Active STT Recognition Engine:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            RadioGroup<String>(
              groupValue: settings.sttEngine,
              onChanged: (val) {
                if (val != null) _changeSttEngine(val);
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Vosk Offline ASR (Primary Edge)'),
                    subtitle: Text('Uses bundled on-device Kaldi model'),
                    value: 'vosk',
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Device STT (System Fallback)'),
                    subtitle: Text('Uses Android onDevice speech recognizer'),
                    value: 'device',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelPathCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vosk Acoustic Model Configuration',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const Text(
              'Configurable asset path for evaluating recognition accuracy across different accents (e.g. Nigerian-accented English vs standard US):',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelPathController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Model Asset Path',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Apply Model Path'),
                onPressed: _saveModelPath,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value,
      {bool? isOk, Widget? trailing}) {
    Color? textColor;
    if (isOk != null) {
      textColor = isOk ? Colors.green.shade700 : Colors.red.shade700;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ],
      ),
    );
  }
}
