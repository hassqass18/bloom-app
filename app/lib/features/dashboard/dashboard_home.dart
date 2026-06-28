import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/bloom_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart' show today;
import '../../data/models/models2.dart';
import '../../data/models/models3.dart';
import '../../providers.dart';
import '../goals/goal_create_flow.dart';
import '../goals/goal_detail_screen.dart';
import '../reinforcement/reinforcement_engine.dart';
import '../voice/voice_session_screen.dart';

/// The home cockpit: goals + their tasks, progress bars for what matters, and a
/// journal that takes manual input or a Bloom-guided session.
class DashboardHome extends ConsumerStatefulWidget {
  const DashboardHome({super.key});

  @override
  ConsumerState<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends ConsumerState<DashboardHome> {
  final _uuid = const Uuid();
  final _journal = TextEditingController();
  final Set<String> _doneToday = {};
  Future<_DashData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _journal.dispose();
    super.dispose();
  }

  Future<_DashData> _load() async {
    final repo = ref.read(entriesRepositoryProvider);
    final goals = await repo.activeGoals();
    final steps = await repo.allActiveSteps();
    final d = today();
    _doneToday.clear();
    final perGoalDone = <String, int>{};
    final perGoalTotal = <String, int>{};
    for (final s in steps) {
      perGoalTotal[s.goalId] = (perGoalTotal[s.goalId] ?? 0) + 1;
      final log = await repo.stepLogFor(s.id, d);
      if (log != null && log.done) {
        _doneToday.add(s.id);
        perGoalDone[s.goalId] = (perGoalDone[s.goalId] ?? 0) + 1;
      }
    }
    final journal = await repo.journalForDay(d);
    final areas = await repo.trackedAreas();
    return _DashData(goals, steps, perGoalDone, perGoalTotal, journal, areas);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _toggleStep(GoalStep s, bool done) async {
    final repo = ref.read(entriesRepositoryProvider);
    await repo.logStep(StepLog(id: _uuid.v4(), stepId: s.id, day: today(), done: done));
    setState(() => done ? _doneToday.add(s.id) : _doneToday.remove(s.id));
    if (done) {
      final r = await ReinforcementEngine().generate(progress: {'doneToday': 1, 'consistency': 0.6});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.text)));
      }
    }
  }

  Future<void> _saveJournal() async {
    final t = _journal.text.trim();
    if (t.isEmpty) return;
    _journal.clear();
    await ref.read(entriesRepositoryProvider).saveJournal(
        JournalEntryV3(id: _uuid.v4(), day: today(), body: t, mode: 'manual'));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashData>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BLOOM', style: Theme.of(context).textTheme.headlineSmall),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const _MeSheet())),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Your day, growing into something you can see.',
                style: TextStyle(color: BloomColors.whisper)),
            const SizedBox(height: 16),

            // ---- Progress ----
            Text('YOUR PROGRESS',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            if (d != null && d.goals.isEmpty)
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('No goals yet.'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _openNewGoal,
                    child: const Text('SET YOUR FIRST GOAL'),
                  ),
                ]),
              ),
            if (d != null)
              ...d.goals.map((g) {
                final total = d.perGoalTotal[g.id] ?? 0;
                final done = d.perGoalDone[g.id] ?? 0;
                final frac = total == 0 ? 0.0 : done / total;
                return GlassCard(
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GoalDetailScreen(goalId: g.id)));
                    _refresh();
                  },
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.definiteStatement,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 8,
                        backgroundColor: BloomColors.obsidian,
                        color: BloomColors.gold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("$done of $total steps today",
                        style: const TextStyle(fontSize: 11, color: BloomColors.whisper)),
                  ]),
                );
              }),
            if (d != null && d.goals.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _openNewGoal,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New goal'),
                ),
              ),

            // ---- Today's steps ----
            if (d != null && d.steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text("TODAY'S STEPS",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              ...d.steps.map((s) => GlassCard(
                    padding: EdgeInsets.zero,
                    child: CheckboxListTile(
                      value: _doneToday.contains(s.id),
                      onChanged: (v) => _toggleStep(s, v ?? false),
                      activeColor: BloomColors.gold,
                      title: Text(s.title),
                      subtitle: (s.ifCue != null && s.ifCue!.isNotEmpty)
                          ? Text('If ${s.ifCue}, then ${s.thenAction}',
                              style: const TextStyle(fontSize: 12))
                          : null,
                    ),
                  )),
            ],

            // ---- Journal ----
            const SizedBox(height: 16),
            Text('JOURNAL',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (d != null && d.journal.isNotEmpty) ...[
                  ...d.journal.map((j) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• ${j.body}'),
                      )),
                  const Divider(),
                ],
                TextField(
                  controller: _journal,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: 'Write today in your own words…'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  FilledButton(onPressed: _saveJournal, child: const Text('SAVE')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const VoiceSessionScreen()));
                        _refresh();
                      },
                      icon: const Icon(Icons.graphic_eq),
                      label: const Text('Talk it through'),
                    ),
                  ),
                ]),
              ]),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openNewGoal() async {
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const GoalCreateFlow()));
    if (created == true) _refresh();
  }
}

class _DashData {
  final List<Goal> goals;
  final List<GoalStep> steps;
  final Map<String, int> perGoalDone;
  final Map<String, int> perGoalTotal;
  final List<JournalEntryV3> journal;
  final List<TrackedArea> areas;
  _DashData(this.goals, this.steps, this.perGoalDone, this.perGoalTotal, this.journal, this.areas);
}

/// Lightweight account/privacy sheet reached from the dashboard avatar.
class _MeSheet extends StatelessWidget {
  const _MeSheet();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(padding: const EdgeInsets.all(16), children: const [
        ListTile(leading: Icon(Icons.lock_outline), title: Text('Your data is private'),
            subtitle: Text('On-device first. AI voice is optional.')),
        ListTile(leading: Icon(Icons.favorite_outline), title: Text('Bloom is a wellness companion'),
            subtitle: Text('Not a medical device or a replacement for therapy.')),
      ]),
    );
  }
}
