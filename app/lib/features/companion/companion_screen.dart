import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/safety/crisis.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart' show Thought, today;
import '../../providers.dart';

/// The pocket therapist that remembers. Unlike a fresh chatbot, Bloom shows what
/// it remembers about you over time, and reflects gently on what you share.
class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});

  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen> {
  final _input = TextEditingController();
  final _uuid = const Uuid();
  final List<_Msg> _chat = [];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _chat.add(_Msg(text, mine: true)));

    if (Crisis.looksLikeCrisis(text)) {
      await Crisis.show(context);
    }
    // Persist as a thought so it becomes part of the longitudinal record.
    await ref
        .read(entriesRepositoryProvider)
        .addThought(Thought(id: _uuid.v4(), day: today(), body: text));

    final reply = _reflect(text);
    if (mounted) setState(() => _chat.add(_Msg(reply, mine: false)));
  }

  /// A gentle, MI-style reflection. (When cloud AI is enabled this is where the
  /// memory-aware Edge response would slot in; offline we mirror warmly.)
  String _reflect(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('tired') || lower.contains('exhausted')) {
      return "It sounds like today asked a lot of you. Resting is allowed. 💜";
    }
    if (lower.contains('proud') || lower.contains('did it') || lower.contains('finally')) {
      return "I hear something to be proud of in that. I'll remember it. 🌱";
    }
    if (lower.contains('want') || lower.contains('hope') || lower.contains('wish')) {
      return "That sounds like it matters to you. What's one tiny step toward it?";
    }
    return "Thank you for telling me. I'm keeping it with the rest of your story. 🌸";
  }

  @override
  Widget build(BuildContext context) {
    final memAsync = ref.watch(memoryProvider);
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Bloom', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                memAsync.when(
                  data: (m) => GlassCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WHAT I REMEMBER ABOUT YOU',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontSize: 13, letterSpacing: 1.5)),
                          const SizedBox(height: 6),
                          Text(
                            m == null || m.summary.isEmpty
                                ? "We're just getting to know each other. The more you "
                                    "share, the more I'll remember — across days, not just today."
                                : (m.summary['who']?.toString() ??
                                    m.summary.values.join(' · ')),
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (m != null && m.values.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: m.values
                                  .map((v) => Chip(
                                        label: Text(v.toString()),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                for (final m in _chat) _bubble(m),
                if (_chat.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "Tell me anything that's on your mind. I'll listen, remember, "
                      'and reflect — no judgment. 🌸',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: "What's on your mind?",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _send, child: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) => Align(
        alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: m.mine
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(m.text),
        ),
      );
}

class _Msg {
  final String text;
  final bool mine;
  _Msg(this.text, {required this.mine});
}
