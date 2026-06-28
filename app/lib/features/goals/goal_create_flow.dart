import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/models2.dart';
import '../../providers.dart';
import 'plan_builder.dart';

/// The Goal Definition Engine UI: broad wish → definite, measurable goal →
/// tiny if-then steps (Goal-Setting Theory + WOOP + Tiny Habits).
class GoalCreateFlow extends ConsumerStatefulWidget {
  const GoalCreateFlow({super.key});

  @override
  ConsumerState<GoalCreateFlow> createState() => _GoalCreateFlowState();
}

class _GoalCreateFlowState extends ConsumerState<GoalCreateFlow> {
  final _wish = TextEditingController();
  final _uuid = const Uuid();
  bool _building = false;
  BuiltPlan? _plan;

  late TextEditingController _definite;
  late TextEditingController _metric;
  late TextEditingController _target;
  late TextEditingController _unit;
  late TextEditingController _anchor;
  String _cadence = 'daily';
  final List<StepDraft> _steps = [];

  @override
  void dispose() {
    _wish.dispose();
    _definite.dispose();
    _metric.dispose();
    _target.dispose();
    _unit.dispose();
    _anchor.dispose();
    super.dispose();
  }

  Future<void> _makeDefinite() async {
    if (_wish.text.trim().isEmpty) return;
    setState(() => _building = true);
    final plan = await PlanBuilder().build(_wish.text.trim());
    _definite = TextEditingController(text: plan.definiteStatement);
    _metric = TextEditingController(text: plan.metric);
    _target = TextEditingController(text: plan.targetValue?.toString() ?? '');
    _unit = TextEditingController(text: plan.unit);
    _anchor = TextEditingController(text: plan.valueAnchor);
    _cadence = plan.cadence;
    _steps
      ..clear()
      ..addAll(plan.steps);
    setState(() {
      _plan = plan;
      _building = false;
    });
  }

  Future<void> _save() async {
    final repo = ref.read(entriesRepositoryProvider);
    final goalId = _uuid.v4();
    final goal = Goal(
      id: goalId,
      wish: _wish.text.trim(),
      definiteStatement: _definite.text.trim(),
      domain: _plan?.domain,
      metric: _metric.text.trim(),
      targetValue: double.tryParse(_target.text.trim()),
      unit: _unit.text.trim(),
      cadence: _cadence,
      valueAnchor: _anchor.text.trim(),
      obstacles: _plan?.obstacles ?? const [],
      stage: 'preparation',
    );
    await repo.saveGoal(goal);
    for (var i = 0; i < _steps.length; i++) {
      final s = _steps[i];
      await repo.saveStep(GoalStep(
        id: _uuid.v4(),
        goalId: goalId,
        title: s.title,
        ifCue: s.ifCue,
        thenAction: s.thenAction,
        anchorRoutine: s.anchorRoutine,
        bctId: s.bctId,
        orderIdx: i,
      ));
    }
    ref.invalidate(activeGoalsProvider);
    ref.invalidate(activeStepsProvider);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New goal')),
      body: _plan == null ? _wishStep() : _reviewStep(),
    );
  }

  Widget _wishStep() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('What do you wish for?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            "Say it however it comes — broad is fine. Bloom will help you make it "
            "definite, then shrink it into tiny steps you can actually do. 🌸",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _wish,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. "I want to save more money" or "fewer outbursts"',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _building ? null : _makeDefinite,
            icon: _building
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_building ? 'Thinking…' : 'Make it definite'),
          ),
        ],
      );

  Widget _reviewStep() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Your definite goal',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _definite,
            maxLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _target,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _metric,
            decoration: const InputDecoration(labelText: 'What we count', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _cadence,
            decoration: const InputDecoration(labelText: 'How often', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Daily')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            ],
            onChanged: (v) => setState(() => _cadence = v ?? 'daily'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _anchor,
            decoration: const InputDecoration(
                labelText: 'Who this makes you (your "why")', border: OutlineInputBorder()),
          ),
          if ((_plan?.obstacles ?? const []).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Obstacles to plan around (WOOP)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _plan!.obstacles
                  .map((o) => Chip(label: Text(o)))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Your tiny if-then steps',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Kept small on purpose — they survive low-energy days.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          ..._steps.asMap().entries.map((e) => _stepEditor(e.key, e.value)),
          TextButton.icon(
            onPressed: () => setState(() => _steps.add(StepDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Add a step'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save this goal 🌱')),
          const SizedBox(height: 40),
        ],
      );

  Widget _stepEditor(int i, StepDraft s) => Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextFormField(
              initialValue: s.title,
              decoration: const InputDecoration(labelText: 'Step', isDense: true),
              onChanged: (v) => s.title = v,
            ),
            TextFormField(
              initialValue: s.ifCue,
              decoration: const InputDecoration(labelText: 'If (cue)', isDense: true),
              onChanged: (v) => s.ifCue = v,
            ),
            TextFormField(
              initialValue: s.thenAction,
              decoration: const InputDecoration(labelText: 'then I will…', isDense: true),
              onChanged: (v) => s.thenAction = v,
            ),
          ]),
        ),
      );
}
