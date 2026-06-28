import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local offline-first store (sqflite). Mirrors the Supabase schema closely
/// enough to capture everything offline, plus a sync_queue for outbound ops
/// and a meta table for sync watermarks / first-run flags.
///
/// v2 adds the behavior-change tables (goals, steps, sessions, measures,
/// memory, reinforcement, consent, reminders, passive signals).
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static const _dbVersion = 3;

  Database? _db;
  Future<Database> get _database async => _db ??= await _open();

  /// v1 entry tables (indexed by day).
  static const entryTables = [
    'journal_entries', 'thoughts', 'emotions', 'activities', 'money_entries',
  ];

  /// All tables that participate in two-way sync (pushed + pulled).
  static const syncTables = [
    'journal_entries', 'thoughts', 'emotions', 'activities', 'money_entries',
    'identities',
    'goals', 'goal_steps', 'step_logs', 'sessions', 'session_turns',
    'measures', 'reinforcements', 'memory_profile', 'consents', 'reminders',
    'passive_signals',
    // v3 holistic domains
    'practice_logs', 'fitness_logs', 'nutrition_logs', 'journal', 'tracked_areas',
  ];

  /// TEXT columns that hold JSON locally (decode → object on push; encode on pull).
  static const jsonColumns = <String, List<String>>{
    'journal_entries': ['payload'],
    'activities': ['tags'],
    'goals': ['obstacles'],
    'measures': ['items'],
    'memory_profile': ['summary', 'core_values', 'patterns'],
    'passive_signals': ['value'],
  };

  /// Columns stored as INTEGER 0/1 locally but BOOLEAN remotely.
  static const boolColumns = <String, List<String>>{
    'step_logs': ['done'],
    'session_turns': ['change_talk'],
    'consents': ['granted'],
    'reminders': ['enabled'],
    'passive_signals': ['reconciled'],
    'practice_logs': ['done'],
  };

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'bloom.db');
    return openDatabase(path,
        version: _dbVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int v) async {
    await _createV1(db);
    await _createV2(db);
    await _createV3(db);
  }

  Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) await _createV2(db);
    if (from < 3) await _createV3(db);
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
days(
        day TEXT PRIMARY KEY,
        mood INTEGER,
        mood_note TEXT,
        updated_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
journal_entries(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, kind TEXT NOT NULL,
        payload TEXT NOT NULL, words INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
thoughts(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, body TEXT NOT NULL,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
emotions(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, emotion TEXT NOT NULL,
        valence INTEGER, energy INTEGER, note TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
activities(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, title TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT '[]', duration_min INTEGER, note TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
money_entries(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, direction TEXT NOT NULL,
        amount REAL NOT NULL, currency TEXT NOT NULL DEFAULT 'KES',
        category TEXT, note TEXT, updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
identities(
        id TEXT PRIMARY KEY, label TEXT NOT NULL, emoji TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    // Outbound sync queue: one row per pending push.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
sync_queue(
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        tbl TEXT NOT NULL, op TEXT NOT NULL, row_id TEXT,
        payload TEXT NOT NULL, created_at TEXT NOT NULL)''');
    // Key/value meta: sync watermarks, onboarding flag, etc.
    await db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)');
    for (final t in entryTables) {
      await db.execute('CREATE INDEX idx_${t}_day ON $t(day)');
    }
  }

  Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
goals(
        id TEXT PRIMARY KEY, wish TEXT NOT NULL, definite_statement TEXT NOT NULL,
        domain TEXT, metric TEXT, target_value REAL, unit TEXT, cadence TEXT,
        value_anchor TEXT, obstacles TEXT NOT NULL DEFAULT '[]',
        stage TEXT NOT NULL DEFAULT 'preparation',
        status TEXT NOT NULL DEFAULT 'active',
        start_date TEXT NOT NULL, target_date TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
goal_steps(
        id TEXT PRIMARY KEY, goal_id TEXT NOT NULL, title TEXT NOT NULL,
        if_cue TEXT, then_action TEXT, anchor_routine TEXT, bct_id TEXT,
        order_idx INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
step_logs(
        id TEXT PRIMARY KEY, step_id TEXT NOT NULL, day TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 1, note TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
sessions(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, mode TEXT NOT NULL DEFAULT 'adaptive',
        summary TEXT, mood INTEGER, started_at TEXT NOT NULL, ended_at TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
session_turns(
        id TEXT PRIMARY KEY, session_id TEXT NOT NULL, q_id TEXT,
        question TEXT NOT NULL, answer TEXT, com_b_factor TEXT,
        change_talk INTEGER NOT NULL DEFAULT 0, order_idx INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
measures(
        id TEXT PRIMARY KEY, instrument TEXT NOT NULL, day TEXT NOT NULL,
        score REAL, items TEXT NOT NULL DEFAULT '{}',
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
reinforcements(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL,
        goal_id TEXT, source TEXT, delivered_at TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
memory_profile(
        id TEXT PRIMARY KEY, summary TEXT NOT NULL DEFAULT '{}',
        core_values TEXT NOT NULL DEFAULT '[]', patterns TEXT NOT NULL DEFAULT '[]',
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
consents(
        id TEXT PRIMARY KEY, scope TEXT NOT NULL, granted INTEGER NOT NULL DEFAULT 0,
        granted_at TEXT, revoked_at TEXT, updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
reminders(
        id TEXT PRIMARY KEY, kind TEXT NOT NULL, schedule TEXT,
        enabled INTEGER NOT NULL DEFAULT 1, last_fired_at TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS
passive_signals(
        id TEXT PRIMARY KEY, source TEXT NOT NULL, kind TEXT,
        value TEXT NOT NULL DEFAULT '{}', observed_at TEXT NOT NULL,
        reconciled INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_steps_goal ON goal_steps(goal_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_steplogs_day ON step_logs(day)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_turns_session ON session_turns(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_measures_day ON measures(instrument, day)');
  }

  Future<void> _createV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS practice_logs(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, kind TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0, note TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fitness_logs(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, activity TEXT NOT NULL,
        duration_min INTEGER, intensity TEXT, note TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nutrition_logs(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, kind TEXT NOT NULL, label TEXT,
        kcal REAL, water_ml INTEGER, note TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal(
        id TEXT PRIMARY KEY, day TEXT NOT NULL, body TEXT NOT NULL DEFAULT '',
        mode TEXT NOT NULL DEFAULT 'manual', source TEXT,
        updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tracked_areas(
        id TEXT PRIMARY KEY, label TEXT NOT NULL, domain TEXT, target REAL,
        unit TEXT, cadence TEXT, updated_at TEXT NOT NULL, deleted_at TEXT)''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_practice_day ON practice_logs(day)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fitness_day ON fitness_logs(day)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_nutrition_day ON nutrition_logs(day)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_day ON journal(day)');
  }

  // ---------- v3: holistic domain queries ----------
  Future<List<Map<String, dynamic>>> practiceForDay(String day) async {
    final db = await _database;
    return db.query('practice_logs',
        where: 'day = ? AND deleted_at IS NULL', whereArgs: [day], orderBy: 'updated_at');
  }

  Future<List<Map<String, dynamic>>> fitnessForDay(String day) async {
    final db = await _database;
    return db.query('fitness_logs',
        where: 'day = ? AND deleted_at IS NULL', whereArgs: [day], orderBy: 'updated_at');
  }

  Future<List<Map<String, dynamic>>> nutritionForDay(String day) async {
    final db = await _database;
    return db.query('nutrition_logs',
        where: 'day = ? AND deleted_at IS NULL', whereArgs: [day], orderBy: 'updated_at');
  }

  Future<List<Map<String, dynamic>>> journalForDay(String day) async {
    final db = await _database;
    return db.query('journal',
        where: 'day = ? AND deleted_at IS NULL', whereArgs: [day], orderBy: 'updated_at DESC');
  }

  Future<List<Map<String, dynamic>>> trackedAreas() async {
    final db = await _database;
    return db.query('tracked_areas', where: 'deleted_at IS NULL', orderBy: 'updated_at');
  }

  // ---------- writes (local, with sync enqueue) ----------
  Future<void> upsertDay(Map<String, dynamic> map) async {
    final db = await _database;
    await db.insert('days', map, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueue(db, 'days', 'upsert', map['day'] as String, map);
  }

  Future<void> upsertEntry(String table, String id, Map<String, dynamic> map) async {
    final db = await _database;
    await db.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueue(db, table, 'upsert', id, map);
  }

  Future<void> softDelete(String table, String id) async {
    final db = await _database;
    final ts = DateTime.now().toUtc().toIso8601String();
    await db.update(table, {'deleted_at': ts, 'updated_at': ts},
        where: 'id = ?', whereArgs: [id]);
    await _enqueue(db, table, 'delete', id, {'id': id, 'deleted_at': ts});
  }

  /// Write a row that came FROM the cloud — no enqueue (avoids sync loops).
  Future<void> putLocal(String table, Map<String, dynamic> map) async {
    final db = await _database;
    await db.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _enqueue(Database db, String tbl, String op, String rowId,
      Map<String, dynamic> payload) async {
    await db.insert('sync_queue', {
      'tbl': tbl, 'op': op, 'row_id': rowId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ---------- generic reads ----------
  Future<Map<String, dynamic>?> getDay(String day) async {
    final db = await _database;
    final rows = await db.query('days', where: 'day = ?', whereArgs: [day], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> entriesForDay(String table, String day) async {
    final db = await _database;
    return db.query(table,
        where: 'day = ? AND deleted_at IS NULL', whereArgs: [day], orderBy: 'updated_at');
  }

  Future<List<Map<String, dynamic>>> allRows(String table,
      {String orderBy = 'updated_at DESC', int? limit}) async {
    final db = await _database;
    return db.query(table,
        where: 'deleted_at IS NULL', orderBy: orderBy, limit: limit);
  }

  Future<List<String>> loggedDays({int limit = 90}) async {
    final db = await _database;
    final rows = await db.query('days', columns: ['day'], orderBy: 'day DESC', limit: limit);
    return rows.map((r) => r['day'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> moodSeries({int limit = 30}) async {
    final db = await _database;
    return db.query('days',
        columns: ['day', 'mood'],
        where: 'mood IS NOT NULL', orderBy: 'day DESC', limit: limit);
  }

  Future<Map<String, dynamic>> monthMoney(String monthPrefix) async {
    final db = await _database;
    final like = '$monthPrefix%';
    final totals = await db.rawQuery('''
      SELECT direction, SUM(amount) total FROM money_entries
      WHERE day LIKE ? AND deleted_at IS NULL GROUP BY direction''', [like]);
    final byCat = await db.rawQuery('''
      SELECT COALESCE(category,'Uncategorized') category, SUM(amount) total
      FROM money_entries
      WHERE day LIKE ? AND direction='spent' AND deleted_at IS NULL
      GROUP BY category ORDER BY total DESC''', [like]);
    double spent = 0, earned = 0;
    for (final r in totals) {
      final t = (r['total'] as num?)?.toDouble() ?? 0;
      if (r['direction'] == 'spent') {
        spent = t;
      } else {
        earned = t;
      }
    }
    return {'spent': spent, 'earned': earned, 'byCategory': byCat};
  }

  Future<int> totalWords() async {
    final db = await _database;
    final r = await db.rawQuery(
        'SELECT SUM(words) s FROM journal_entries WHERE deleted_at IS NULL');
    return ((r.first['s'] as num?) ?? 0).toInt();
  }

  // ---------- v2: goals / steps / step logs ----------
  Future<List<Map<String, dynamic>>> goals({String status = 'active'}) async {
    final db = await _database;
    return db.query('goals',
        where: 'deleted_at IS NULL AND status = ?', whereArgs: [status],
        orderBy: 'updated_at DESC');
  }

  Future<Map<String, dynamic>?> goalById(String id) async {
    final db = await _database;
    final r = await db.query('goals', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<List<Map<String, dynamic>>> stepsForGoal(String goalId) async {
    final db = await _database;
    return db.query('goal_steps',
        where: 'goal_id = ? AND deleted_at IS NULL', whereArgs: [goalId],
        orderBy: 'order_idx');
  }

  Future<List<Map<String, dynamic>>> allActiveSteps() async {
    final db = await _database;
    return db.rawQuery('''
      SELECT s.* FROM goal_steps s
      JOIN goals g ON g.id = s.goal_id
      WHERE s.deleted_at IS NULL AND g.deleted_at IS NULL
        AND s.status='active' AND g.status='active'
      ORDER BY s.order_idx''');
  }

  Future<Map<String, dynamic>?> stepLogFor(String stepId, String day) async {
    final db = await _database;
    final r = await db.query('step_logs',
        where: 'step_id = ? AND day = ? AND deleted_at IS NULL',
        whereArgs: [stepId, day], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  /// Consistency rate (0..1) for a step over the last [windowDays] days.
  Future<double> consistencyRate(String stepId, {int windowDays = 14}) async {
    final db = await _database;
    final since = DateTime.now()
        .subtract(Duration(days: windowDays))
        .toIso8601String()
        .substring(0, 10);
    final r = await db.rawQuery('''
      SELECT COUNT(*) c FROM step_logs
      WHERE step_id = ? AND day >= ? AND done = 1 AND deleted_at IS NULL''',
        [stepId, since]);
    final done = (r.first['c'] as int?) ?? 0;
    return (done / windowDays).clamp(0.0, 1.0);
  }

  /// Per-day done-count series across all steps of a goal (for the automaticity curve).
  Future<List<Map<String, dynamic>>> goalAdherenceSeries(String goalId,
      {int windowDays = 66}) async {
    final db = await _database;
    final since = DateTime.now()
        .subtract(Duration(days: windowDays))
        .toIso8601String()
        .substring(0, 10);
    return db.rawQuery('''
      SELECT l.day day, COUNT(*) done FROM step_logs l
      JOIN goal_steps s ON s.id = l.step_id
      WHERE s.goal_id = ? AND l.day >= ? AND l.done = 1 AND l.deleted_at IS NULL
      GROUP BY l.day ORDER BY l.day''', [goalId, since]);
  }

  // ---------- v2: sessions / turns ----------
  Future<List<Map<String, dynamic>>> recentSessions({int limit = 30}) async {
    final db = await _database;
    return db.query('sessions',
        where: 'deleted_at IS NULL', orderBy: 'started_at DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> turnsForSession(String sessionId) async {
    final db = await _database;
    return db.query('session_turns',
        where: 'session_id = ? AND deleted_at IS NULL', whereArgs: [sessionId],
        orderBy: 'order_idx');
  }

  // ---------- v2: measures ----------
  Future<List<Map<String, dynamic>>> measureSeries(String instrument,
      {int limit = 30}) async {
    final db = await _database;
    return db.query('measures',
        where: 'instrument = ? AND deleted_at IS NULL', whereArgs: [instrument],
        orderBy: 'day DESC', limit: limit);
  }

  // ---------- v2: reinforcement ----------
  Future<List<Map<String, dynamic>>> recentReinforcements({int limit = 20}) async {
    final db = await _database;
    return db.query('reinforcements',
        where: 'deleted_at IS NULL', orderBy: 'day DESC, updated_at DESC', limit: limit);
  }

  // ---------- v2: memory ----------
  Future<Map<String, dynamic>?> latestMemory() async {
    final db = await _database;
    final r = await db.query('memory_profile',
        where: 'deleted_at IS NULL', orderBy: 'updated_at DESC', limit: 1);
    return r.isEmpty ? null : r.first;
  }

  // ---------- v2: consents ----------
  Future<Map<String, dynamic>?> consentFor(String scope) async {
    final db = await _database;
    final r = await db.query('consents',
        where: 'scope = ? AND deleted_at IS NULL', whereArgs: [scope], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  // ---------- v2: reminders ----------
  Future<List<Map<String, dynamic>>> reminders() async {
    final db = await _database;
    return db.query('reminders', where: 'deleted_at IS NULL', orderBy: 'kind');
  }

  // ---------- export / wipe (privacy) ----------
  Future<Map<String, List<Map<String, dynamic>>>> exportAll() async {
    final db = await _database;
    final out = <String, List<Map<String, dynamic>>>{};
    final tables = ['days', ...syncTables];
    for (final t in tables) {
      out[t] = await db.query(t);
    }
    return out;
  }

  Future<void> wipeAll() async {
    final db = await _database;
    final tables = ['days', ...syncTables, 'sync_queue', 'meta'];
    for (final t in tables) {
      await db.delete(t);
    }
  }

  // ---------- sync queue ----------
  Future<List<Map<String, dynamic>>> pendingOps({int limit = 200}) async {
    final db = await _database;
    return db.query('sync_queue', orderBy: 'seq', limit: limit);
  }

  Future<void> clearOp(int seq) async {
    final db = await _database;
    await db.delete('sync_queue', where: 'seq = ?', whereArgs: [seq]);
  }

  Future<int> pendingCount() async {
    final db = await _database;
    final r = await db.rawQuery('SELECT COUNT(*) c FROM sync_queue');
    return (r.first['c'] as int?) ?? 0;
  }

  // ---------- meta (k/v) ----------
  Future<String?> getMeta(String k) async {
    final db = await _database;
    final r = await db.query('meta', where: 'k = ?', whereArgs: [k], limit: 1);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  Future<void> setMeta(String k, String v) async {
    final db = await _database;
    await db.insert('meta', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
