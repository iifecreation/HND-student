// About screen presenting academic viva details, student metadata, and safety disclaimer.

import 'package:flutter/material.dart';

/// Screen displaying HND project metadata, offline architecture notes, and mandatory safety notices.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About PrinterDoc'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Project Title Banner
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.print_outlined,
                      size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'PrinterDoc',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Voice-Controlled Edge Expert System for Diagnosing Printer Faults',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade600),
                    ),
                    child: Text(
                      'Fully Offline · Zero Cloud ML · Edge Architecture',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Academic Submission Metadata
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academic Submission',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _metaRow('Qualification',
                      'Higher National Diploma (HND) in Computing'),
                  _metaRow('Student Name', '[Student Name - Viva Candidate]'),
                  _metaRow('Project Supervisor', '[Supervisor Name]'),
                  _metaRow('App Version', 'v1.0.0 (Release Build)'),
                  _metaRow('Platform Target', 'Android (API 24+, 3 GB RAM)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Architectural Principles (Viva Defense)
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Core Architectural Principles',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  const Text(
                    '• Pure-Dart Engine: Reasoning, knowledge models, stemmer, and dialogue state are decoupled from Flutter and execute with sub-5ms latency.\n'
                    '• Explainable AI: Forward chaining with MYCIN certainty factor algebra provides full reasoning transparency (no black-box ML).\n'
                    '• Edge Privacy: Raw microphone audio never leaves the device; speech-to-text (Vosk) and synthesis (local TTS) run in airplane mode.\n'
                    '• Strict Offline Integrity: Release manifest declares zero internet permissions.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mandatory Safety Disclaimer (SPEC Section 11 & FR9)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade700, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: Colors.amber.shade900, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'SAFETY & USAGE DISCLAIMER',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Guidance only. Switch off and unplug the printer from electrical mains before opening access panels or touching internal components.\n\n'
                  'If there is smoke, sparks, or a burning smell (Fault F20), stop immediately and call a qualified technician.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
