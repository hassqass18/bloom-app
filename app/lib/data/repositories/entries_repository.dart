import '../local/local_db.dart';
import '../models/models.dart';
import '../models/models2.dart';
import '../models/models3.dart';

/// Offline-first repository. Every write lands in the local DB immediately and
/// is enqueued for sync. Reads come from the local DB (single source of truth
/// for capture). Sync is handled separately by SyncEngine.
class EntriesRepository {
  final LocalDb _db = LocalDb.instance;

  // ---- v1 writes ----
  Future<void> saveMood(String day, int? mood, {String? note}) =>
      _db.upsertDay(DayLog(day: day, mood: mood, moodNote: note).toMap());

  Future<void> addJournal(JournalEntry e) => _db.upsertEntry('journal_entries', e.id, e.toMap());
  Future<void> addThought(Thought e) => _db.upsertEntry('thoughts', e.id, e.toMap());
  Future<void> addEmotion(Emotion e) => _db.upsertEntry('emotions', e.id, e.toMap());
  Future<void> addActivity(Activity e) => _db.upsertEntry('activities', e.id, e.toMap());
  Future<void> addMoney(MoneyEntry e) => _db.upsertEntry('money_entries', e.id, e.toMap());

  Future<void> deleteEntry(String table, String id) => _db.softDelete(table, id);

  Future<void> addIdentity(String id, String label, String? emoji) => _db.upsertEntry(
        'identities', id,
        {'id': id, 'label': label, 'emoji': emoji,
         'updated_at': DateTime.now().toUtc().toIso8601String()},
      );

  Future<List<String>> identityLabels() async =>
      (await _db.allRows('identities', orderBy: 'updated_at'))
          .map((r) => r['label'] as String)
          .toList();

  // ---- v1 reads ----
  Future<DayLog?> day(String day) async {
    final m = await _db.getDay(day);
    return m == null ? null : DayLog.fromMap(m);
  }

  Future<List<JournalEntry>> journalFor(String day) async =>
      (await _db.entriesForDay('journal_entries', day)).map(JournalEntry.fromMap).toList();
  Future<List<Thought>> thoughtsFor(String day) async =>
      (await _db.entriesForDay('thoughts', day)).map(Thought.fromMap).toList();
  Future<List<Emotion>> emotionsFor(String day) async =>
      (await _db.entriesForDay('emotions', day)).map(Emotion.fromMap).toList();
  Future<List<Activity>> activitiesFor(String day) async =>
      (await _db.entriesForDay('activities', day)).map(Activity.fromMap).toList();
  Future<List<MoneyEntry>> moneyFor(String day) async =>
      (await _db.entriesForDay('money_entries', day)).map(MoneyEntry.fromMap).toList();

  Future<List<String>> loggedDays({int limit = 90}) => _db.loggedDays(limit: limit);
  Future<int> pendingSyncCount() => _db.pendingCount();

  // ---- aggregates (Money / Insights) ----
  Future<Map<String, dynamic>> monthMoney(String monthPrefix) => _db.monthMoney(monthPrefix);
  Future<List<Map<String, dynamic>>> moodSeries({int limit = 30}) => _db.moodSeries(limit: limit);
  Future<int> totalWords() => _db.totalWords();

  // ======================================================================
  // v2 — behavior-change engine
  // ======================================================================

  // ---- goals & steps ----
  Future<void> saveGoal(Goal g) => _db.upsertEntry('goals', g.id, g.toMap());
  Future<void> saveStep(GoalStep s) => _db.upsertEntry('goal_steps', s.id, s.toMap());
  Future<void> dropGoal(String id) => _db.softDelete('goals', id);

  Future<List<Goal>> activeGoals() async =>
      (await _db.goals(status: 'active')).map(Goal.fromMap).toList();

  Future<Goal?> goalById(String id) async {
    final m = await _db.goalById(id);
    return m == null ? null : Goal.fromMap(m);
  }

  Future<List<GoalStep>> stepsForGoal(String goalId) async =>
      (await _db.stepsForGoal(goalId)).map(GoalStep.fromMap).toList();

  Future<List<GoalStep>> allActiveSteps() async =>
      (await _db.allActiveSteps()).map(GoalStep.fromMap).toList();

  Future<void> logStep(StepLog l) => _db.upsertEntry('step_logs', l.id, l.toMap());

  Future<StepLog?> stepLogFor(String stepId, String day) async {
    final m = await _db.stepLogFor(stepId, day);
    return m == null ? null : StepLog.fromMap(m);
  }

  Future<double> consistencyRate(String stepId, {int windowDays = 14}) =>
      _db.consistencyRate(stepId, windowDays: windowDays);

  Future<List<Map<String, dynamic>>> goalAdherenceSeries(String goalId,
          {int windowDays = 66}) =>
      _db.goalAdherenceSeries(goalId, windowDays: windowDays);

  // ---- sessions & turns ----
  Future<void> saveSession(BloomSession s) => _db.upsertEntry('sessions', s.id, s.toMap());
  Future<void> saveTurn(SessionTurn t) => _db.upsertEntry('session_turns', t.id, t.toMap());

  Future<List<BloomSession>> recentSessions({int limit = 30}) async =>
      (await _db.recentSessions(limit: limit)).map(BloomSession.fromMap).toList();

  Future<List<SessionTurn>> turnsForSession(String sessionId) async =>
      (await _db.turnsForSession(sessionId)).map(SessionTurn.fromMap).toList();

  // ---- measures (MBC/ROM) ----
  Future<void> saveMeasure(Measure m) => _db.upsertEntry('measures', m.id, m.toMap());
  Future<List<Measure>> measureSeries(String instrument, {int limit = 30}) async =>
      (await _db.measureSeries(instrument, limit: limit)).map(Measure.fromMap).toList();

  // ---- reinforcement ----
  Future<void> saveReinforcement(Reinforcement r) =>
      _db.upsertEntry('reinforcements', r.id, r.toMap());
  Future<List<Reinforcement>> recentReinforcements({int limit = 20}) async =>
      (await _db.recentReinforcements(limit: limit)).map(Reinforcement.fromMap).toList();

  // ---- longitudinal memory ----
  Future<void> saveMemory(MemoryProfile m) =>
      _db.upsertEntry('memory_profile', m.id, m.toMap());
  Future<MemoryProfile?> latestMemory() async {
    final m = await _db.latestMemory();
    return m == null ? null : MemoryProfile.fromMap(m);
  }

  // ---- consent ----
  Future<void> setConsent(Consent c) => _db.upsertEntry('consents', c.id, c.toMap());
  Future<Consent?> consentFor(String scope) async {
    final m = await _db.consentFor(scope);
    return m == null ? null : Consent.fromMap(m);
  }

  // ---- reminders ----
  Future<void> saveReminder(ReminderPref r) => _db.upsertEntry('reminders', r.id, r.toMap());
  Future<List<ReminderPref>> reminders() async =>
      (await _db.reminders()).map(ReminderPref.fromMap).toList();

  // ---- passive signals ----
  Future<void> savePassive(PassiveSignal s) =>
      _db.upsertEntry('passive_signals', s.id, s.toMap());

  // ======================================================================
  // v3 — holistic daily domains
  // ======================================================================
  Future<void> savePractice(PracticeLog l) => _db.upsertEntry('practice_logs', l.id, l.toMap());
  Future<List<PracticeLog>> practiceForDay(String day) async =>
      (await _db.practiceForDay(day)).map(PracticeLog.fromMap).toList();

  Future<void> saveFitness(FitnessLog l) => _db.upsertEntry('fitness_logs', l.id, l.toMap());
  Future<List<FitnessLog>> fitnessForDay(String day) async =>
      (await _db.fitnessForDay(day)).map(FitnessLog.fromMap).toList();

  Future<void> saveNutrition(NutritionLog l) => _db.upsertEntry('nutrition_logs', l.id, l.toMap());
  Future<List<NutritionLog>> nutritionForDay(String day) async =>
      (await _db.nutritionForDay(day)).map(NutritionLog.fromMap).toList();

  Future<void> saveJournal(JournalEntryV3 j) => _db.upsertEntry('journal', j.id, j.toMap());
  Future<List<JournalEntryV3>> journalForDay(String day) async =>
      (await _db.journalForDay(day)).map(JournalEntryV3.fromMap).toList();

  Future<void> saveTrackedArea(TrackedArea a) => _db.upsertEntry('tracked_areas', a.id, a.toMap());
  Future<void> deleteTrackedArea(String id) => _db.softDelete('tracked_areas', id);
  Future<List<TrackedArea>> trackedAreas() async =>
      (await _db.trackedAreas()).map(TrackedArea.fromMap).toList();

  // ---- privacy: export / wipe ----
  Future<Map<String, List<Map<String, dynamic>>>> exportAll() => _db.exportAll();
  Future<void> wipeAll() => _db.wipeAll();
}
