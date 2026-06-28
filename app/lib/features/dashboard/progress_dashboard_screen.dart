import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bloom_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/sparkline.dart';
import '../../data/models/models2.dart';
import '../../providers.dart';
import '../measures/who5_checkin.dart';

/// "See it, not feel it." Quantified progress: wellbeing trajectory (WHO-5),
/// per-goal automaticity curves, consistency, and a perceived-vs-actual nudge.
class ProgressDashboardScreen extends ConsumerStatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  ConsumerState<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends ConsumerState<ProgressDashboardScreen> {
  Future<_DashData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashData> _load() async {
    final repo = ref.read(entriesRepositoryProvider);
    final moods = await repo.moodSeries();
    final words = await repo.totalWords();
    final money = await repo.monthMoney(DateTime.now().toIso8601String().substring(0, 7));
    final who5 = await repo.measureSeries('who5');
    final goals = await repo.activeGoals();
    final curves = <String, List<double>>{};
    for (final g in goals) {
      final s = await repo.goalAdherenceSeries(g.id);
      curves[g.id] = s.map((r) => ((r['done'] as num?) ?? 0).toDouble()).toList();
    }
    final avgMood = moods.isEmpty
        ? null
        : moods.map((m) => (m['mood'] as int)).reduce((a, b) => a + b) / moods.length;
    final wellbeing = who5.reversed.map((m) => m.score ?? 0).toList();
    return _DashData(avgMood, moods.length, words,
        (money['spent'] as double?) ?? 0, wellbeing, goals, curves);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashData>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Your growth', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('See what is really going on — not just how it feels. 🌸',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            // Wellbeing trajectory
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('WELLBEING · WHO-5',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontSize: 13, letterSpacing: 1.4)),
                      TextButton(
                        onPressed: () async {
                          final done = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(builder: (_) => const Who5Checkin()));
                          if (done == true) _refresh();
                        },
                        child: const Text('Check in'),
                      ),
                    ],
                  ),
                  if (d != null) Sparkline(d.wellbeing),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Quick stats
            if (d != null)
              Row(
                children: [
                  _stat('Avg mood', d.avgMood?.toStringAsFixed(1) ?? '—'),
                  _stat('Days logged', '${d.days}'),
                  _stat('Words', '${d.words}'),
                ],
              ),
            const SizedBox(height: 16),
            // Per-goal automaticity
            Text('HABITS SETTING IN',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 14, letterSpacing: 1.4)),
            const SizedBox(height: 8),
            if (d != null && d.goals.isEmpty)
              const Text('Set a goal to start tracking it here.',
                  style: TextStyle(color: BloomColors.whisper)),
            if (d != null)
              ...d.goals.map((g) => GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.definiteStatement,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Sparkline(d.curves[g.id] ?? const [], height: 44),
                      ],
                    ),
                  )),
            const SizedBox(height: 16),
            // Perceived vs actual
            const GlassCard(
              child: Text(
                '“Am I spending my time the way I think I am?” As you log more, Bloom '
                'will show you the honest answer here — gently, never as judgment.',
                style: TextStyle(color: BloomColors.mist, height: 1.5),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: BloomColors.gold)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: BloomColors.whisper)),
            ],
          ),
        ),
      );
}

class _DashData {
  final double? avgMood;
  final int days;
  final int words;
  final double spent;
  final List<double> wellbeing;
  final List<Goal> goals;
  final Map<String, List<double>> curves;
  _DashData(this.avgMood, this.days, this.words, this.spent, this.wellbeing,
      this.goals, this.curves);
}
