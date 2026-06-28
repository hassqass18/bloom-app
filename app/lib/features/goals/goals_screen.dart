import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart' show today;
import '../../data/models/models2.dart';
import '../../providers.dart';
import '../reinforcement/reinforcement_engine.dart';
import 'goal_create_flow.dart';
import 'goal_detail_screen.dart';

/// The goals home: today's tiny steps to check off + your active goals.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _uuid = const Uuid();
  final Set<String> _doneToday = {};
  bool _loadedDone = false;

  @override
  void initState() {
    super.initState();
    _loadDone();
  }

  Future<void> _loadDone() async {
    final repo = ref.read(entriesRepositoryProvider);
    final steps = await repo.allActiveSteps();
    final d = today();
    for (final s in steps) {
      final log = await repo.stepLogFor(s.id, d);
      if (log != null && log.done) _doneToday.add(s.id);
    }
    if (mounted) setState(() => _loadedDone = true);
  }

  Future<void> _toggleStep(GoalStep s, bool done) async {
    final repo = ref.read(entriesRepositoryProvider);
    await repo.logStep(StepLog(id: _uuid.v4(), stepId: s.id, day: today(), done: done));
    setState(() => done ? _doneToday.add(s.id) : _doneToday.remove(s.id));
    if (done) {
      final rate = await repo.consistencyRate(s.id);
      final r = await ReinforcementEngine().generate(progress: {
        'doneToday': 1,
        'consistency': rate,
      });
      await repo.saveReinforcement(Reinforcement(
          id: _uuid.v4(), day: today(), kind: r.kind, text: r.text, source: 'rules'));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(r.text)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(activeGoalsProvider);
    final stepsAsync = ref.watch(activeStepsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const GoalCreateFlow()));
          if (created == true) {
            ref.invalidate(activeGoalsProvider);
            ref.invalidate(activeStepsProvider);
            await _loadDone();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text("Today's tiny steps",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          stepsAsync.when(
            data: (steps) {
              if (steps.isEmpty) {
                return const _Empty(
                    'No steps yet. Set a goal and Bloom will break it into tiny steps. 🌱');
              }
              return Column(
                children: steps.map((s) {
                  final done = _doneToday.contains(s.id);
                  return GlassCard(
                    padding: EdgeInsets.zero,
                    child: CheckboxListTile(
                      value: _loadedDone ? done : false,
                      onChanged: (v) => _toggleStep(s, v ?? false),
                      title: Text(s.title),
                      subtitle: (s.ifCue != null && s.ifCue!.isNotEmpty)
                          ? Text('If ${s.ifCue}, then ${s.thenAction}',
                              style: const TextStyle(fontSize: 12))
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (_, __) => const _Empty('Could not load steps.'),
          ),
          const SizedBox(height: 24),
          Text('Your goals', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          goalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return const _Empty(
                    'No goals yet. Tap "New goal" to make a wish definite. 🌸');
              }
              return Column(
                children: goals.map((g) => _goalCard(g)).toList(),
              );
            },
            loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (_, __) => const _Empty('Could not load goals.'),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(Goal g) => GlassCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(g.definiteStatement),
          subtitle: Wrap(spacing: 6, children: [
            if ((g.valueAnchor ?? '').isNotEmpty)
              Chip(
                label: Text('🌱 ${g.valueAnchor}'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            Chip(
              label: Text(g.stage),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GoalDetailScreen(goalId: g.id)));
            ref.invalidate(activeGoalsProvider);
            ref.invalidate(activeStepsProvider);
            await _loadDone();
          },
        ),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      );
}
