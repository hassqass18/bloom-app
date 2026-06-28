import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/supabase/supabase_service.dart';
import '../../providers.dart';

/// Gentle self-knowledge: local trends (avg mood, words, this month's money) +
/// the AI "What I'm noticing" weekly card (cloud + signed-in only).
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  List<String> _bullets = const [];
  bool _loadingAi = false;
  String? _aiError;

  Future<Map<String, dynamic>> _localStats() async {
    final repo = ref.read(entriesRepositoryProvider);
    final moods = await repo.moodSeries();
    final words = await repo.totalWords();
    final money = await repo.monthMoney(DateTime.now().toIso8601String().substring(0, 7));
    final avgMood = moods.isEmpty
        ? null
        : moods.map((m) => (m['mood'] as int)).reduce((a, b) => a + b) / moods.length;
    return {'avgMood': avgMood, 'days': moods.length, 'words': words, 'spent': money['spent']};
  }

  Future<void> _refreshAi() async {
    if (!Env.hasCloud || !SupabaseService.isSignedIn) {
      setState(() => _aiError = 'Sign in to get AI insights.');
      return;
    }
    setState(() { _loadingAi = true; _aiError = null; });
    try {
      final res = await SupabaseService.client.functions.invoke('notice');
      final data = res.data as Map?;
      setState(() => _bullets = ((data?['bullets'] as List?) ?? const []).cast<String>());
    } catch (e) {
      setState(() => _aiError = 'Insights unavailable right now.');
    } finally {
      setState(() => _loadingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _localStats(),
      builder: (context, snap) {
        final s = snap.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Insights', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (s != null) ...[
              _stat('Days with a mood', '${s['days']}'),
              _stat('Average mood', s['avgMood'] == null ? '—' : (s['avgMood'] as double).toStringAsFixed(1)),
              _stat('Words written', '${s['words']}'),
              _stat('Spent this month', (s['spent'] as double).toStringAsFixed(0)),
            ],
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("What I'm noticing 🌸", style: TextStyle(fontWeight: FontWeight.w600)),
              TextButton(onPressed: _loadingAi ? null : _refreshAi,
                  child: Text(_loadingAi ? '…' : 'Refresh')),
            ]),
            if (_aiError != null) Text(_aiError!, style: const TextStyle(color: Colors.grey)),
            if (_bullets.isEmpty && _aiError == null)
              const Text('Tap Refresh to see gentle observations from your week.',
                  style: TextStyle(color: Colors.grey)),
            ..._bullets.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• $b'),
                )),
          ],
        );
      },
    );
  }

  Widget _stat(String label, String value) => Card(
        child: ListTile(title: Text(label), trailing: Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      );
}
