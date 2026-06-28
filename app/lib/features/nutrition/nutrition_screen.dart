import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/bloom_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart' show today;
import '../../data/models/models3.dart';
import '../../providers.dart';

/// Nutrition — log meals and water. (Food database lookups later.)
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  final _uuid = const Uuid();
  final _meal = TextEditingController();
  Future<List<NutritionLog>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(entriesRepositoryProvider).nutritionForDay(today());
  }

  @override
  void dispose() {
    _meal.dispose();
    super.dispose();
  }

  void _refresh() =>
      setState(() => _future = ref.read(entriesRepositoryProvider).nutritionForDay(today()));

  Future<void> _addMeal() async {
    final m = _meal.text.trim();
    if (m.isEmpty) return;
    _meal.clear();
    await ref.read(entriesRepositoryProvider).saveNutrition(
        NutritionLog(id: _uuid.v4(), day: today(), kind: 'meal', label: m));
    _refresh();
  }

  Future<void> _addWater() async {
    await ref.read(entriesRepositoryProvider).saveNutrition(
        NutritionLog(id: _uuid.v4(), day: today(), kind: 'water', waterMl: 250));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('NUTRITION', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('A few words per meal is plenty.', style: TextStyle(color: BloomColors.whisper)),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Log a meal', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(controller: _meal,
                decoration: const InputDecoration(hintText: 'e.g. oatmeal & fruit')),
            const SizedBox(height: 8),
            Row(children: [
              FilledButton(onPressed: _addMeal, child: const Text('ADD MEAL')),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                  onPressed: _addWater,
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text('+250ml water')),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<NutritionLog>>(
          future: _future,
          builder: (context, snap) {
            final logs = snap.data ?? const [];
            final water = logs
                .where((l) => l.kind == 'water')
                .fold<int>(0, (a, b) => a + (b.waterMl ?? 0));
            final meals = logs.where((l) => l.kind != 'water').toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (water > 0)
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.water_drop, color: BloomColors.orchid, size: 18),
                    const SizedBox(width: 8),
                    Text('Water today: $water ml'),
                  ]),
                ),
              if (meals.isEmpty && water == 0)
                const Text('Nothing logged yet today.',
                    style: TextStyle(color: BloomColors.whisper)),
              ...meals.map((l) => GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.restaurant, color: BloomColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.label ?? 'meal')),
                    ]),
                  )),
            ]);
          },
        ),
      ],
    );
  }
}
