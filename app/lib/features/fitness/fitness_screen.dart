import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/bloom_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart' show today;
import '../../data/models/models3.dart';
import '../../providers.dart';

/// Fitness — log workouts/movement. (Health Connect / HealthKit auto-read later.)
class FitnessScreen extends ConsumerStatefulWidget {
  const FitnessScreen({super.key});
  @override
  ConsumerState<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends ConsumerState<FitnessScreen> {
  final _uuid = const Uuid();
  final _activity = TextEditingController();
  final _minutes = TextEditingController();
  Future<List<FitnessLog>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(entriesRepositoryProvider).fitnessForDay(today());
  }

  @override
  void dispose() {
    _activity.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _refresh() =>
      setState(() => _future = ref.read(entriesRepositoryProvider).fitnessForDay(today()));

  Future<void> _add() async {
    final a = _activity.text.trim();
    if (a.isEmpty) return;
    final mins = int.tryParse(_minutes.text.trim());
    _activity.clear();
    _minutes.clear();
    await ref.read(entriesRepositoryProvider).saveFitness(
        FitnessLog(id: _uuid.v4(), day: today(), activity: a, durationMin: mins));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('FITNESS', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Even a short walk counts.', style: TextStyle(color: BloomColors.whisper)),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Log movement', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(controller: _activity,
                decoration: const InputDecoration(hintText: 'e.g. walk, gym, yoga')),
            const SizedBox(height: 8),
            TextField(controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'minutes (optional)')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _add, child: const Text('ADD')),
          ]),
        ),
        const SizedBox(height: 12),
        const GlassCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.favorite_border, color: BloomColors.whisper),
            title: Text('Connect your health app'),
            subtitle: Text('Coming soon — read steps & workouts from Health Connect / HealthKit, with your permission.'),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<FitnessLog>>(
          future: _future,
          builder: (context, snap) {
            final logs = snap.data ?? const [];
            if (logs.isEmpty) {
              return const Text('No movement logged yet today.',
                  style: TextStyle(color: BloomColors.whisper));
            }
            return Column(
              children: logs
                  .map((l) => GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          const Icon(Icons.directions_run, color: BloomColors.gold, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l.activity)),
                          if (l.durationMin != null)
                            Text('${l.durationMin} min',
                                style: const TextStyle(color: BloomColors.whisper)),
                        ]),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
