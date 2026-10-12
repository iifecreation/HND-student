// Unit tests for session logging, local file persistence, and user preferences repository.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_doc/app/service_locator.dart';
import 'package:printer_doc/data/session_logger.dart';
import 'package:printer_doc/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DiagnosticSessionLog Model', () {
    test('serializes and deserializes cleanly via JSON', () {
      final now = DateTime.now();
      final original = DiagnosticSessionLog(
        id: 'sess_001',
        timestamp: now,
        initialUtterance: 'printer has paper jam',
        assertedSymptoms: ['paper_jam', 'tray_overfilled'],
        questions: [
          SessionQuestionLog(
            symptomId: 'tray_overfilled',
            question: 'Is the paper tray overfilled?',
            answer: 'yes',
          ),
        ],
        diagnosedFaultId: 'F01',
        diagnosedFaultName: 'Tray Overfill Jam',
        confidence: 0.85,
        outcome: 'resolved',
        inferenceMs: 12,
        totalDurationMs: 4500,
        excludedFaults: ['F02'],
      );

      final json = original.toJson();
      final restored = DiagnosticSessionLog.fromJson(json);

      expect(restored.id, equals('sess_001'));
      expect(restored.initialUtterance, equals('printer has paper jam'));
      expect(restored.assertedSymptoms, equals(['paper_jam', 'tray_overfilled']));
      expect(restored.questions.length, equals(1));
      expect(restored.questions.first.symptomId, equals('tray_overfilled'));
      expect(restored.questions.first.answer, equals('yes'));
      expect(restored.diagnosedFaultId, equals('F01'));
      expect(restored.diagnosedFaultName, equals('Tray Overfill Jam'));
      expect(restored.confidence, closeTo(0.85, 0.001));
      expect(restored.outcome, equals('resolved'));
      expect(restored.inferenceMs, equals(12));
      expect(restored.totalDurationMs, equals(4500));
      expect(restored.excludedFaults, equals(['F02']));
    });

    test('handles null and missing fields gracefully in JSON parsing', () {
      final minimal = DiagnosticSessionLog.fromJson(const {});
      expect(minimal.id, isEmpty);
      expect(minimal.initialUtterance, isEmpty);
      expect(minimal.assertedSymptoms, isEmpty);
      expect(minimal.questions, isEmpty);
      expect(minimal.diagnosedFaultId, isNull);
      expect(minimal.confidence, isNull);
      expect(minimal.outcome, equals('unknown'));
      expect(minimal.inferenceMs, equals(0));
    });
  });

  group('SessionLogger File Persistence', () {
    late Directory tempDir;
    late File testFile;
    late SessionLogger logger;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('printer_doc_log_test_');
      testFile = File('${tempDir.path}/test_sessions.jsonl');
      logger = SessionLogger(overrideFile: testFile);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('appends sessions and reads them in reverse chronological order', () async {
      final s1 = DiagnosticSessionLog(
        id: '1',
        timestamp: DateTime(2026, 1, 1),
        initialUtterance: 'jam in tray',
        assertedSymptoms: ['paper_jam'],
        questions: [],
        outcome: 'resolved',
        inferenceMs: 5,
        totalDurationMs: 1000,
      );
      final s2 = DiagnosticSessionLog(
        id: '2',
        timestamp: DateTime(2026, 1, 2),
        initialUtterance: 'toner is low',
        assertedSymptoms: ['low_toner'],
        questions: [],
        outcome: 'resolved',
        inferenceMs: 8,
        totalDurationMs: 1500,
      );

      await logger.logSession(s1);
      await logger.logSession(s2);

      final sessions = await logger.getSessions();
      expect(sessions.length, equals(2));
      // Most recent first
      expect(sessions[0].id, equals('2'));
      expect(sessions[1].id, equals('1'));
    });

    test('ignores malformed lines and parses remaining valid entries', () async {
      final s1 = DiagnosticSessionLog(
        id: 'valid_1',
        timestamp: DateTime.now(),
        initialUtterance: 'valid',
        assertedSymptoms: [],
        questions: [],
        outcome: 'resolved',
        inferenceMs: 2,
        totalDurationMs: 500,
      );

      await logger.logSession(s1);
      // Append a corrupted line directly
      await testFile.writeAsString('NOT_VALID_JSON\n\n', mode: FileMode.append);

      final sessions = await logger.getSessions();
      expect(sessions.length, equals(1));
      expect(sessions.first.id, equals('valid_1'));
    });

    test('clears session logs and exports formatted JSON string', () async {
      final s1 = DiagnosticSessionLog(
        id: 'exp_1',
        timestamp: DateTime(2026, 3, 1),
        initialUtterance: 'test export',
        assertedSymptoms: ['paper_jam'],
        questions: [],
        outcome: 'resolved',
        inferenceMs: 4,
        totalDurationMs: 2000,
      );

      await logger.logSession(s1);
      final exportedJson = await logger.exportAsJson();
      expect(exportedJson, contains('exp_1'));
      expect(exportedJson, contains('test export'));

      await logger.clearSessions();
      final afterClear = await logger.getSessions();
      expect(afterClear, isEmpty);
    });
  });

  group('SettingsRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns sensible default edge settings initially', () async {
      final repo = SettingsRepository();
      final settings = await repo.getSettings();

      expect(settings.speechRate, equals(0.45));
      expect(settings.voiceOutputEnabled, isTrue);
      expect(settings.autoListenEnabled, isFalse);
      expect(settings.sttEngine, equals('vosk'));
      expect(settings.voskModelPath, equals('assets/models/vosk-model-small-en-us-0.15.zip'));
      expect(settings.lastInferenceMs, equals(0));
      expect(settings.lastSttLatencyMs, equals(0));
    });

    test('persists and updates individual user preferences', () async {
      final repo = SettingsRepository();

      await repo.setSpeechRate(0.55);
      await repo.setVoiceOutputEnabled(false);
      await repo.setAutoListenEnabled(true);
      await repo.setSttEngine('device');
      await repo.setVoskModelPath('assets/models/custom_accent.zip');
      await repo.recordTimings(inferenceMs: 15, sttLatencyMs: 320);

      final updated = await repo.getSettings();
      expect(updated.speechRate, closeTo(0.55, 0.001));
      expect(updated.voiceOutputEnabled, isFalse);
      expect(updated.autoListenEnabled, isTrue);
      expect(updated.sttEngine, equals('device'));
      expect(updated.voskModelPath, equals('assets/models/custom_accent.zip'));
      expect(updated.lastInferenceMs, equals(15));
      expect(updated.lastSttLatencyMs, equals(320));
    });

    test('resets settings back to defaults', () async {
      final repo = SettingsRepository();
      await repo.setSpeechRate(0.8);
      await repo.setSttEngine('device');

      await repo.resetToDefaults();
      final reset = await repo.getSettings();

      expect(reset.speechRate, equals(0.45));
      expect(reset.sttEngine, equals('vosk'));
    });
  });

  group('ServiceLocator Data Services', () {
    test('provides sessionLogger and settingsRepository singletons', () {
      final locator = ServiceLocator();
      expect(locator.sessionLogger, isNotNull);
      expect(locator.settingsRepository, isNotNull);
    });
  });
}
