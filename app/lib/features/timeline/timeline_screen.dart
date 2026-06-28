import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

/// Minimal timeline: the days you've logged, newest first. (Mosaic + walls later.)
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  late Future<List<String>> _days;

  @override
  void initState() {
    super.initState();
    _days = ref.read(entriesRepositoryProvider).loggedDays();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _days,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final days = snap.data!;
        if (days.isEmpty) {
          return const Center(child: Text('Your first entry is the start of everything 🌸'));
        }
        return ListView.separated(
          itemCount: days.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => ListTile(
            leading: const Icon(Icons.local_florist_outlined),
            title: Text(days[i]),
            onTap: () {
              ref.read(selectedDayProvider.notifier).state = days[i];
              // Navigation to a day-detail view comes later.
            },
          ),
        );
      },
    );
  }
}
