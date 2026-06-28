import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/models/models.dart' show today;
import 'data/models/models2.dart';
import 'data/models/models3.dart';
import 'data/repositories/entries_repository.dart';

/// Shared providers.
final entriesRepositoryProvider = Provider<EntriesRepository>((ref) => EntriesRepository());

/// The day currently being viewed/edited (ISO yyyy-MM-dd). Defaults to today.
final selectedDayProvider = StateProvider<String>((ref) => today());

/// Active goals (refreshable: `ref.invalidate(activeGoalsProvider)`).
final activeGoalsProvider = FutureProvider<List<Goal>>(
    (ref) => ref.read(entriesRepositoryProvider).activeGoals());

/// Today's active steps across all goals.
final activeStepsProvider = FutureProvider<List<GoalStep>>(
    (ref) => ref.read(entriesRepositoryProvider).allActiveSteps());

/// The longitudinal memory profile (the pocket-therapist's recollection).
final memoryProvider = FutureProvider<MemoryProfile?>(
    (ref) => ref.read(entriesRepositoryProvider).latestMemory());

/// Areas the user marked important — drive the dashboard progress bars.
final trackedAreasProvider = FutureProvider<List<TrackedArea>>(
    (ref) => ref.read(entriesRepositoryProvider).trackedAreas());
