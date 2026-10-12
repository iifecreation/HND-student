// Diagnostic session history audit screen displaying past sessions and evaluation exports.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/service_locator.dart';
import '../../data/session_logger.dart';

/// Screen listing logged diagnostic sessions, questions asked, outcomes, and benchmark latencies.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ServiceLocator _services = ServiceLocator();
  List<DiagnosticSessionLog> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await _services.sessionLogger.getSessions();
    if (mounted) {
      setState(() {
        _sessions = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportHistory() async {
    final json = await _services.sessionLogger.exportAsJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session audit log copied to clipboard as JSON.'),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Session History?'),
        content: const Text(
          'This will delete all logged sessions from the local JSON-lines file. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _services.sessionLogger.clearSessions();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Session History'),
        actions: [
          if (_sessions.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Export JSON',
              onPressed: _exportHistory,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear History',
              onPressed: _confirmClear,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      const Text(
                        'No diagnostic sessions recorded yet.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Completed diagnosis sessions will automatically appear here.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _buildSessionCard(session, theme);
                  },
                ),
    );
  }

  Widget _buildSessionCard(DiagnosticSessionLog session, ThemeData theme) {
    final dateStr =
        '${session.timestamp.year}-${session.timestamp.month.toString().padLeft(2, '0')}-${session.timestamp.day.toString().padLeft(2, '0')} ${session.timestamp.hour.toString().padLeft(2, '0')}:${session.timestamp.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.diagnosedFaultName ?? 'Unresolved / In Progress',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _buildOutcomeChip(session.outcome),
          ],
        ),
        subtitle: Text(
          '$dateStr · "${session.initialUtterance}"',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Initial Utterance', session.initialUtterance),
                _infoRow(
                  'Diagnosed Fault',
                  session.diagnosedFaultId != null
                      ? '${session.diagnosedFaultId}: ${session.diagnosedFaultName}'
                      : 'None concluded',
                ),
                if (session.confidence != null)
                  _infoRow(
                    'Certainty Factor',
                    '${(session.confidence! * 100).toStringAsFixed(0)}%',
                  ),
                _infoRow(
                  'Symptoms Asserted',
                  session.assertedSymptoms.isEmpty
                      ? 'None'
                      : session.assertedSymptoms.join(', '),
                ),
                _infoRow('Inference Latency', '${session.inferenceMs} ms'),
                _infoRow(
                  'Total Session Time',
                  '${(session.totalDurationMs / 1000).toStringAsFixed(1)} s',
                ),
                if (session.questions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Questions Asked:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  for (final q in session.questions)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• ${q.question} → Answer: ${q.answer.toUpperCase()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                if (session.excludedFaults.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Excluded Faults (FR10): ${session.excludedFaults.join(', ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeChip(String outcome) {
    Color bg;
    Color fg;
    switch (outcome.toLowerCase()) {
      case 'resolved':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case 'escalated':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case 'did_not_work':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        outcome.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
