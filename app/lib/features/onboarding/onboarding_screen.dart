import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/local_db.dart';
import '../../providers.dart';

/// First-run: pick a few identities ("who you're becoming") + choose how much
/// the AI companion joins in. Warm, optional, one screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _options = <String, String>{
    'Reader': '📖', 'Learner': '✨', 'Word-Collector': '📜', 'Notice-er of Wins': '🌸',
    'Creator': '🎨', 'Reflector': '🪞', 'Builder': '🦋', 'Gentle with Myself': '💕',
  };
  final _selected = <String>{};
  String _aiMode = 'deep';
  bool _busy = false;

  Future<void> _finish() async {
    setState(() => _busy = true);
    final repo = ref.read(entriesRepositoryProvider);
    const uuid = Uuid();
    for (final label in _selected) {
      await repo.addIdentity(uuid.v4(), label, _options[label]);
    }
    await LocalDb.instance.setMeta('ai_mode', _aiMode);
    await LocalDb.instance.setMeta('onboarded', '1');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Bloom 🌸')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Pick a few words for who you're becoming.",
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          const Text('You can change these any time.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.entries.map((e) {
              final on = _selected.contains(e.key);
              return FilterChip(
                label: Text('${e.value} ${e.key}'),
                selected: on,
                onSelected: (_) => setState(() =>
                    on ? _selected.remove(e.key) : _selected.add(e.key)),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          const Text('How much should the companion join in?',
              style: TextStyle(fontWeight: FontWeight.w600)),
          RadioGroup<String>(
            groupValue: _aiMode,
            onChanged: (v) => setState(() => _aiMode = v!),
            child: const Column(
              children: [
                RadioListTile<String>(
                  value: 'deep',
                  title: Text('Deep — a gentle follow-up after each prompt'),
                ),
                RadioListTile<String>(
                  value: 'quick',
                  title: Text('Quick — just me and the page (no AI)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _finish,
            child: Text(_busy ? '…' : 'These are mine'),
          ),
        ],
      ),
    );
  }
}
