import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/models.dart' show today;
import '../../data/models/models2.dart';
import '../../providers.dart';

/// WHO-5 Well-Being Index — a brief, validated, non-clinical wellbeing check-in
/// (Measurement-Based Care). Score 0–100; higher is better. Opt-in, low burden.
class Who5Checkin extends ConsumerStatefulWidget {
  const Who5Checkin({super.key});

  @override
  ConsumerState<Who5Checkin> createState() => _Who5CheckinState();
}

class _Who5CheckinState extends ConsumerState<Who5Checkin> {
  static const _items = [
    'I have felt cheerful and in good spirits',
    'I have felt calm and relaxed',
    'I have felt active and vigorous',
    'I woke up feeling fresh and rested',
    'My daily life has been filled with things that interest me',
  ];
  final List<double> _vals = List.filled(5, 3);

  Future<void> _save() async {
    final raw = _vals.fold<double>(0, (a, b) => a + b); // 0..25
    final score = raw * 4; // 0..100
    final items = {for (var i = 0; i < 5; i++) 'q${i + 1}': _vals[i].round()};
    await ref.read(entriesRepositoryProvider).saveMeasure(Measure(
          id: const Uuid().v4(),
          instrument: 'who5',
          day: today(),
          score: score,
          items: items,
        ));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wellbeing check-in')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Over the last two weeks…',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('0 = at no time · 5 = all of the time',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          ..._items.asMap().entries.map((e) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value),
                      Slider(
                        value: _vals[e.key],
                        min: 0,
                        max: 5,
                        divisions: 5,
                        label: _vals[e.key].round().toString(),
                        onChanged: (v) => setState(() => _vals[e.key] = v),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save check-in')),
          const SizedBox(height: 8),
          const Text(
            'This is a wellbeing reflection, not a medical test. If you are struggling, '
            'please reach out to someone you trust. 💜',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
