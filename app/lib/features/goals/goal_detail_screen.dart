import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/sparkline.dart';
import '../../data/models/models2.dart';
import '../../providers.dart';

/// Goal detail: the definite statement, its tiny if-then steps, each step's
/// consistency, and the goal's automaticity curve (habit "setting" over time).
class GoalDetailScreen extends ConsumerStatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  Goal? _goal;
  List<GoalStep> _steps = [];
  final Map<String, double> _consistency = {};
  List<double> _curve = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(entriesRepositoryProvider);
    final g = await repo.goalById(widget.goalId);
    final steps = await repo.stepsForGoal(widget.goalId);
    for (final s in steps) {
      _consistency[s.id] = await repo.consistencyRate(s.id);
    }
    final series = await repo.goalAdherenceSeries(widget.goalId);
    _curve = series.map((r) => ((r['done'] as num?) ?? 0).toDouble()).toList();
    if (mounted) {
      setState(() {
        _goal = g;
        _steps = steps;
        _loading = false;
      });
    }
  }

  Future<void> _drop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Let this goal go?'),
        content: const Text('It will be archived gently — no judgment. 💜'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Let it go')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(entriesRepositoryProvider).dropGoal(widget.goalId);
      ref.invalidate(activeGoalsProvider);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _goal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal'),
        actions: [
          IconButton(onPressed: _drop, icon: const Icon(Icons.archive_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
              ? const Center(child: Text('Goal not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(g.definiteStatement,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, children: [
                      if ((g.valueAnchor ?? '').isNotEmpty)
                        Chip(label: Text('🌱 ${g.valueAnchor}')),
                      Chip(label: Text('Stage: ${g.stage}')),
                      if ((g.cadence ?? '').isNotEmpty) Chip(label: Text(g.cadence!)),
                    ]),
                    if (g.targetValue != null) ...[
                      const SizedBox(height: 8),
                      Text('Target: ${g.targetValue} ${g.unit ?? ''} — ${g.metric ?? ''}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Habit setting in 🌱',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text(
                              'Daily steps you completed. Habits take ~66 days to feel '
                              'automatic — missing one day is fine.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Sparkline(_curve),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Your tiny steps',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 8),
                    ..._steps.map(_stepCard),
                    if ((g.obstacles).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Obstacles you planned around',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: g.obstacles.map((o) => Chip(label: Text(o.toString()))).toList(),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _stepCard(GoalStep s) {
    final rate = ((_consistency[s.id] ?? 0) * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(s.title,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('$rate%', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            if ((s.ifCue ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('If ${s.ifCue}, then ${s.thenAction}',
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_consistency[s.id] ?? 0).clamp(0.0, 1.0)),
          ],
        ),
      ),
    );
  }
}
