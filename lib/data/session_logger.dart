// Logs diagnostic sessions, symptoms, questions, outcomes, and latency metrics to local JSON-lines files.

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Single question and user reply recorded during a diagnostic dialogue session.
class SessionQuestionLog {
  final String symptomId;
  final String question;
  final String answer;

  SessionQuestionLog({
    required this.symptomId,
    required this.question,
    required this.answer,
  });

  Map<String, dynamic> toJson() => {
        'symptomId': symptomId,
        'question': question,
        'answer': answer,
      };

  factory SessionQuestionLog.fromJson(Map<String, dynamic> json) {
    return SessionQuestionLog(
      symptomId: json['symptomId'] as String? ?? '',
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }
}

/// Complete diagnostic session audit record (implements FR11).
class DiagnosticSessionLog {
  final String id;
  final DateTime timestamp;
  final String initialUtterance;
  final List<String> assertedSymptoms;
  final List<SessionQuestionLog> questions;
  final String? diagnosedFaultId;
  final String? diagnosedFaultName;
  final double? confidence;
  final String outcome; // 'resolved', 'did_not_work', 'escalated', 'abandoned'
  final int inferenceMs;
  final int totalDurationMs;
  final List<String> excludedFaults;

  DiagnosticSessionLog({
    required this.id,
    required this.timestamp,
    required this.initialUtterance,
    required this.assertedSymptoms,
    required this.questions,
    this.diagnosedFaultId,
    this.diagnosedFaultName,
    this.confidence,
    required this.outcome,
    required this.inferenceMs,
    required this.totalDurationMs,
    this.excludedFaults = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'initialUtterance': initialUtterance,
        'assertedSymptoms': assertedSymptoms,
        'questions': questions.map((q) => q.toJson()).toList(),
        'diagnosedFaultId': diagnosedFaultId,
        'diagnosedFaultName': diagnosedFaultName,
        'confidence': confidence,
        'outcome': outcome,
        'inferenceMs': inferenceMs,
        'totalDurationMs': totalDurationMs,
        'excludedFaults': excludedFaults,
      };

  factory DiagnosticSessionLog.fromJson(Map<String, dynamic> json) {
    return DiagnosticSessionLog(
      id: json['id'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      initialUtterance: json['initialUtterance'] as String? ?? '',
      assertedSymptoms: (json['assertedSymptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      questions: (json['questions'] as List<dynamic>?)
              ?.map((e) =>
                  SessionQuestionLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      diagnosedFaultId: json['diagnosedFaultId'] as String?,
      diagnosedFaultName: json['diagnosedFaultName'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      outcome: json['outcome'] as String? ?? 'unknown',
      inferenceMs: (json['inferenceMs'] as num?)?.toInt() ?? 0,
      totalDurationMs: (json['totalDurationMs'] as num?)?.toInt() ?? 0,
      excludedFaults: (json['excludedFaults'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Service managing append-only local file persistence for diagnostic history.
class SessionLogger {
  static const String defaultFileName = 'printer_doc_sessions.jsonl';
  final File? overrideFile;

  /// Creates a SessionLogger with an optional file injected for unit tests.
  SessionLogger({this.overrideFile});

  Future<File> _resolveFile() async {
    final file = overrideFile;
    if (file != null) return file;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$defaultFileName');
  }

  /// Appends a new session record to the JSON-lines audit file.
  Future<void> logSession(DiagnosticSessionLog session) async {
    final file = await _resolveFile();
    final jsonLine = jsonEncode(session.toJson());
    await file.writeAsString('$jsonLine\n', mode: FileMode.append, flush: true);
  }

  /// Loads all saved sessions, ordered from most recent to oldest.
  Future<List<DiagnosticSessionLog>> getSessions() async {
    final file = await _resolveFile();
    if (!await file.exists()) return [];

    final lines = await file.readAsLines();
    final results = <DiagnosticSessionLog>[];
    for (final line in lines) {
      final clean = line.trim();
      if (clean.isEmpty) continue;
      try {
        final dynamic decoded = jsonDecode(clean);
        if (decoded is Map<String, dynamic>) {
          results.add(DiagnosticSessionLog.fromJson(decoded));
        }
      } catch (_) {
        // Skip malformed lines to preserve overall log readability.
      }
    }
    // Return newest sessions first for history view.
    return results.reversed.toList();
  }

  /// Clears all stored sessions.
  Future<void> clearSessions() async {
    final file = await _resolveFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Exports the session history as formatted JSON string for evaluation reports.
  Future<String> exportAsJson() async {
    final sessions = await getSessions();
    return const JsonEncoder.withIndent('  ').convert(
      sessions.map((s) => s.toJson()).toList(),
    );
  }
}
