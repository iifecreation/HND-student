// Detailed diagnosis result screen showing confidence bar, fix steps, and rule explanations.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../knowledge/fault.dart';
import '../viewmodels/diagnosis_viewmodel.dart';

/// Screen presenting the full expert system diagnosis, solution steps, and explanation facility.
class DiagnosisScreen extends StatelessWidget {
  final Fault? faultOverride;

  const DiagnosisScreen({super.key, this.faultOverride});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiagnosisViewModel>();
    final theme = Theme.of(context);

    final candidate = vm.currentCandidate;
    final fault = faultOverride ?? vm.currentFault;

    if (fault == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnosis Result')),
        body: const Center(
          child: Text('No active diagnosis available. Start a session first.'),
        ),
      );
    }

    final cf = candidate != null && candidate.faultId == fault.id
        ? candidate.cf
        : 1.0;
    final cfPercent = (cf * 100).toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnosis & Fix Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card: Fault Name, Category, Severity & Confidence
          _buildHeaderCard(context, fault, cf, cfPercent, theme),
          const SizedBox(height: 16),

          // Technician warning banner if required
          if (fault.technician) _buildTechnicianWarning(theme),
          if (fault.technician) const SizedBox(height: 16),

          // Fix Steps Checklist / Stepper
          _buildStepsCard(context, vm, fault, theme),
          const SizedBox(height: 16),

          // Explanation Facility ("Why this?")
          _buildExplanationCard(context, vm, fault, theme),
          const SizedBox(height: 16),

          // Ranked Alternatives
          if (vm.candidateRankings.length > 1)
            _buildAlternativesCard(context, vm, fault, theme),

          const SizedBox(height: 24),

          // Outcome resolution buttons (FR10)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('This Fixed It'),
                  onPressed: () {
                    vm.confirmFixed();
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Did Not Work'),
                  onPressed: () {
                    vm.confirmDidNotWork();
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Fault fault, double cf,
      String cfPercent, ThemeData theme) {
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
                  fault.id,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                _buildSeverityChip(fault.severity),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fault.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              fault.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diagnostic Certainty',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '$cfPercent%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: cf,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: cf >= 0.75
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(String severity) {
    Color bg;
    Color fg;
    switch (severity.toLowerCase()) {
      case 'critical':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case 'high':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      case 'medium':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      default:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildTechnicianWarning(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.engineering, color: Colors.red.shade800, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Technician Service Recommended',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This fault involves internal hardware or electrical components. Switch off and unplug the printer before inspection.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard(BuildContext context, DiagnosisViewModel vm,
      Fault fault, ThemeData theme) {
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
                  'Step-by-Step Fix',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: const Text('Read All'),
                  onPressed: () {
                    final allSteps = fault.steps
                        .asMap()
                        .entries
                        .map((e) => 'Step ${e.key + 1}: ${e.value}')
                        .join('. ');
                    vm.tts.speak(allSteps);
                  },
                ),
              ],
            ),
            const Divider(),
            for (int i = 0; i < fault.steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fault.steps[i],
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_down, size: 18),
                      tooltip: 'Speak Step',
                      onPressed: () =>
                          vm.tts.speak('Step ${i + 1}: ${fault.steps[i]}'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard(BuildContext context, DiagnosisViewModel vm,
      Fault fault, ThemeData theme) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(Icons.psychology, color: theme.colorScheme.primary),
        title: const Text(
          'Explanation: Why This Diagnosis?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: const Text(
          'View fired production rules and certainty evidence',
          style: TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The MYCIN inference engine evaluated rule conditions against observed symptoms and combined certainty factors:',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final candidate in vm.candidateRankings
                    .where((c) => c.faultId == fault.id))
                  ...candidate.firedRules.map((fired) {
                    final rule = fired.rule;
                    final cfContrib =
                        (fired.ruleCf * 100).toStringAsFixed(0);
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                rule.id,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                              Text(
                                'Contribution: +$cfContrib%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rule.why,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesCard(BuildContext context, DiagnosisViewModel vm,
      Fault currentFault, ThemeData theme) {
    final alternatives =
        vm.candidateRankings.where((c) => c.faultId != currentFault.id).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ranked Alternatives',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            for (final alt in alternatives)
              if (vm.getFaultById(alt.faultId) != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(vm.getFaultById(alt.faultId)!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(vm.getFaultById(alt.faultId)!.summary,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    '${(alt.cf * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () {
                    final altFault = vm.getFaultById(alt.faultId);
                    if (altFault != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DiagnosisScreen(faultOverride: altFault),
                        ),
                      );
                    }
                  },
                ),
          ],
        ),
      ),
    );
  }
}
