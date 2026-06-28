import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

/// Gentle monthly money view: this month's spent/earned + a soft category list.
/// No stressful charts — just totals and bars. Log money from the Today tab.
class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  late Future<Map<String, dynamic>> _data;
  String get _month => DateTime.now().toIso8601String().substring(0, 7);

  @override
  void initState() {
    super.initState();
    _data = ref.read(entriesRepositoryProvider).monthMoney(_month);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!;
        final spent = (d['spent'] as double);
        final earned = (d['earned'] as double);
        final cats = (d['byCategory'] as List).cast<Map<String, dynamic>>();
        final maxCat = cats.isEmpty
            ? 1.0
            : cats.map((c) => (c['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('This month', style: Theme.of(context).textTheme.headlineSmall),
            Text(_month, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _stat('Spent', spent)),
              Expanded(child: _stat('Earned', earned)),
            ]),
            const SizedBox(height: 24),
            const Text('Where it went', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (cats.isEmpty)
              const Text('No spending logged yet 🌸')
            else
              ...cats.map((c) {
                final total = (c['total'] as num).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${c['category']}'),
                        Text(total.toStringAsFixed(0)),
                      ]),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: (total / maxCat).clamp(0.0, 1.0)),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _stat(String label, double value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(label),
            const SizedBox(height: 4),
            Text(value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}
