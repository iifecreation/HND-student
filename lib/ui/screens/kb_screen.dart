// Searchable knowledge base browser listing faults, categories, and concluding rules.

import 'package:flutter/material.dart';
import '../../app/service_locator.dart';
import '../../knowledge/fault.dart';
import '../../knowledge/kb_loader.dart';
import '../../knowledge/rule.dart';
import 'diagnosis_screen.dart';

/// Screen enabling technicians and viva examiners to inspect the complete knowledge base.
class KbScreen extends StatefulWidget {
  const KbScreen({super.key});

  @override
  State<KbScreen> createState() => _KbScreenState();
}

class _KbScreenState extends State<KbScreen> {
  final ServiceLocator _services = ServiceLocator();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final kb = _services.kb;
    final theme = Theme.of(context);

    if (kb == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Knowledge Base')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final filteredFaults = _filterFaults(kb);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base Browser'),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search faults, symptoms, or IDs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Category Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _categoryChip('all', 'All (${kb.faultList.length})'),
                _categoryChip('paper', 'Paper'),
                _categoryChip('quality', 'Print Quality'),
                _categoryChip('connectivity', 'Connectivity'),
                _categoryChip('hardware', 'Hardware'),
              ],
            ),
          ),
          const Divider(height: 16),

          // Faults List
          Expanded(
            child: filteredFaults.isEmpty
                ? const Center(child: Text('No faults matching search filter.'))
                : ListView.builder(
                    itemCount: filteredFaults.length,
                    itemBuilder: (context, index) {
                      final fault = filteredFaults[index];
                      final concludingRules =
                          kb.rules.where((r) => r.then == fault.id).toList();
                      return _buildFaultCard(context, fault, concludingRules, theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Fault> _filterFaults(KnowledgeBase kb) {
    return kb.faultList.where((fault) {
      final matchesCat =
          _selectedCategory == 'all' || fault.category.toLowerCase() == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          fault.id.toLowerCase().contains(_searchQuery) ||
          fault.name.toLowerCase().contains(_searchQuery) ||
          fault.summary.toLowerCase().contains(_searchQuery);
      return matchesCat && matchesQuery;
    }).toList();
  }

  Widget _categoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => setState(() => _selectedCategory = category),
      ),
    );
  }

  Widget _buildFaultCard(BuildContext context, Fault fault,
      List<Rule> concludingRules, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fault.id,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fault.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Text(
          fault.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Category: ${fault.category.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    if (fault.technician)
                      const Chip(
                        avatar: Icon(Icons.engineering, size: 14),
                        label: Text('Technician Required', style: TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Production Rules (${concludingRules.length} concluding this fault):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                for (final rule in concludingRules)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(rule.id,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('CF: ${(rule.cf * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: theme.colorScheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Conditions (ALL): ${rule.all.join(', ')}',
                            style: const TextStyle(fontSize: 11)),
                        if (rule.any.isNotEmpty)
                          Text('Conditions (ANY): ${rule.any.join(', ')}',
                              style: const TextStyle(fontSize: 11)),
                        if (rule.none.isNotEmpty)
                          Text('Conditions (NONE): ${rule.none.join(', ')}',
                              style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 2),
                        Text('Why: ${rule.why}',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.build, size: 16),
                    label: const Text('View Fix Steps'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiagnosisScreen(faultOverride: fault),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
