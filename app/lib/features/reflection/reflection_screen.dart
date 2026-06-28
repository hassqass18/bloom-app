import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/bloom_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart' show today;
import '../../data/models/models3.dart';
import '../../providers.dart';

/// Reflection & Prayer — log prayer/meditation done-or-not and a daily reflection.
class ReflectionScreen extends ConsumerStatefulWidget {
  const ReflectionScreen({super.key});
  @override
  ConsumerState<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends ConsumerState<ReflectionScreen> {
  final _uuid = const Uuid();
  final _note = TextEditingController();
  Future<List<PracticeLog>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(entriesRepositoryProvider).practiceForDay(today());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _refresh() =>
      setState(() => _future = ref.read(entriesRepositoryProvider).practiceForDay(today()));

  Future<void> _log(String kind, bool done, {String? note}) async {
    await ref.read(entriesRepositoryProvider).savePractice(
        PracticeLog(id: _uuid.v4(), day: today(), kind: kind, done: done, note: note));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('REFLECTION & PRAYER', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('No judgment here — only truth.', style: TextStyle(color: BloomColors.whisper)),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Today', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _chip('🙏 Prayed', () => _log('prayer', true)),
              _chip('— Did not pray', () => _log('prayer', false)),
              _chip('🧘 Meditated', () => _log('meditation', true)),
              _chip('— Did not meditate', () => _log('meditation', false)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('A reflection', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'What is on your heart today?'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                final t = _note.text.trim();
                if (t.isEmpty) return;
                _note.clear();
                await _log('reflection', true, note: t);
              },
              child: const Text('SAVE REFLECTION'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<PracticeLog>>(
          future: _future,
          builder: (context, snap) {
            final logs = snap.data ?? const [];
            if (logs.isEmpty) {
              return const Text('Nothing logged yet today.',
                  style: TextStyle(color: BloomColors.whisper));
            }
            return Column(
              children: logs
                  .map((l) => GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(l.done ? Icons.check_circle : Icons.remove_circle_outline,
                              color: l.done ? BloomColors.gold : BloomColors.whisper, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${l.kind}${l.note != null ? " — ${l.note}" : ""}')),
                        ]),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _chip(String label, VoidCallback onTap) =>
      ActionChip(label: Text(label), onPressed: onTap);
}
