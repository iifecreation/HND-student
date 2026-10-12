// Home diagnostic chat screen with speech I/O, quick replies, and offline mode indicator.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../dialogue/dialogue_state.dart';
import '../viewmodels/diagnosis_viewmodel.dart';
import '../widgets/mic_button.dart';
import 'about_screen.dart';
import 'diagnosis_screen.dart';
import 'history_screen.dart';
import 'kb_screen.dart';
import 'settings_screen.dart';

/// Primary interface for user problem description, dialogue, and diagnostic guidance.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<DiagnosisViewModel>();
      if (!vm.isInitialized) {
        vm.initialize();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      context.read<DiagnosisViewModel>().processUserInput(text);
      _textController.clear();
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiagnosisViewModel>();
    final theme = Theme.of(context);

    // Auto-scroll on new message
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'PrinterDoc',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade700.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade700, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.airplanemode_active,
                      size: 12, color: Colors.green.shade800),
                  const SizedBox(width: 4),
                  Text(
                    'Offline Edge',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Start Over',
            onPressed: vm.startNewSession,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings & Status',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Diagnosis Banner (when diagnosed)
                  if (vm.state == DialogueState.diagnosed &&
                      vm.currentCandidate != null &&
                      vm.currentFault != null)
                    _buildDiagnosisBanner(context, vm),

                  // Chat Message List
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: vm.messages.length,
                      itemBuilder: (context, index) {
                        return _buildChatBubble(vm.messages[index], theme);
                      },
                    ),
                  ),

                  // Live partial transcription bar
                  if (vm.livePartialText.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        'Hearing: "${vm.livePartialText}..."',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                  // Quick Action Chips
                  _buildQuickActionChips(context, vm),

                  // Mic & Text Input Area
                  _buildInputArea(context, vm, theme),
                ],
              ),
            ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.print, size: 40, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'PrinterDoc',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Edge Expert System for Printer Faults',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Diagnose'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Knowledge Base'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KbScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History Logs'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings & Edge Status'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Project'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message, ThemeData theme) {
    final isUser = message.isUser;
    final isAlert = message.isSafetyAlert;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isAlert
              ? Colors.red.shade100
              : (isUser
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isAlert ? Border.all(color: Colors.red.shade700) : null,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isAlert)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.red.shade900),
                    const SizedBox(width: 4),
                    Text(
                      'SAFETY OVERRIDE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: isAlert
                    ? Colors.red.shade900
                    : (isUser ? Colors.white : theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosisBanner(BuildContext context, DiagnosisViewModel vm) {
    final candidate = vm.currentCandidate!;
    final fault = vm.currentFault!;
    final cfPercent = (candidate.cf * 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment_turned_in,
              size: 32, color: Colors.blue.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fault.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Confidence: $cfPercent% · ${fault.category.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiagnosisScreen()),
            ),
            child: const Text('View Fix'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChips(BuildContext context, DiagnosisViewModel vm) {
    final state = vm.state;
    final chips = <Widget>[];

    if (state == DialogueState.questioning) {
      chips.addAll([
        ActionChip(
          avatar: const Icon(Icons.check, size: 16, color: Colors.green),
          label: const Text('Yes'),
          onPressed: vm.answerYes,
        ),
        ActionChip(
          avatar: const Icon(Icons.close, size: 16, color: Colors.red),
          label: const Text('No'),
          onPressed: vm.answerNo,
        ),
        ActionChip(
          avatar: const Icon(Icons.help_outline, size: 16),
          label: const Text('Not Sure'),
          onPressed: vm.answerUnsure,
        ),
        ActionChip(
          avatar: const Icon(Icons.info_outline, size: 16),
          label: const Text('Why ask this?'),
          onPressed: vm.explainWhy,
        ),
      ]);
    } else if (state == DialogueState.guiding) {
      chips.addAll([
        ActionChip(
          avatar: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('Next step'),
          onPressed: vm.nextStep,
        ),
        ActionChip(
          avatar: const Icon(Icons.replay, size: 16),
          label: const Text('Repeat'),
          onPressed: vm.repeatStep,
        ),
        ActionChip(
          avatar: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Previous'),
          onPressed: vm.previousStep,
        ),
        ActionChip(
          avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
          label: const Text('Fixed it!'),
          onPressed: vm.confirmFixed,
        ),
        ActionChip(
          avatar: const Icon(Icons.cancel, size: 16, color: Colors.red),
          label: const Text("Didn't work"),
          onPressed: vm.confirmDidNotWork,
        ),
      ]);
    } else if (state == DialogueState.diagnosed) {
      chips.addAll([
        ActionChip(
          avatar: const Icon(Icons.play_arrow, size: 16),
          label: const Text('Walk through fix'),
          onPressed: () => vm.processUserInput('yes'),
        ),
        ActionChip(
          avatar: const Icon(Icons.help_outline, size: 16),
          label: const Text('Why this diagnosis?'),
          onPressed: vm.explainWhy,
        ),
      ]);
    } else {
      // Collecting state quick category chips
      chips.addAll([
        ActionChip(
          label: const Text('Paper Jam'),
          onPressed: () => vm.processUserInput('paper jam'),
        ),
        ActionChip(
          label: const Text('Faded Print'),
          onPressed: () => vm.processUserInput('print is faded'),
        ),
        ActionChip(
          label: const Text('Streaks / Lines'),
          onPressed: () => vm.processUserInput('streaks on page'),
        ),
        ActionChip(
          label: const Text('Printer Offline'),
          onPressed: () => vm.processUserInput('printer shows offline'),
        ),
      ]);
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _buildInputArea(
      BuildContext context, DiagnosisViewModel vm, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Push-to-talk Mic Button
          MicButton(
            isListening: vm.isListening,
            onPressed: vm.toggleListening,
            size: 54,
          ),
          const SizedBox(width: 12),
          // Text Input Box
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: vm.isListening
                    ? 'Listening to microphone...'
                    : 'Describe issue or answer...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleSend,
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
        ],
      ),
    );
  }
}
