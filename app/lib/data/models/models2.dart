import 'dart:convert';

/// Bloom v2 behavior-change models (goals, steps, sessions, measures, memory,
/// reinforcement, consent, reminders, passive signals).
///
/// Local sqflite stores JSON columns as TEXT and booleans as INTEGER (0/1);
/// `toRemote` converts them to real JSON/bool for Postgres. `fromMap` reads the
/// local TEXT/INT shape.

String _nowIso() => DateTime.now().toUtc().toIso8601String();
String _today() => DateTime.now().toIso8601String().substring(0, 10);

int _b(dynamic v) => (v == true || v == 1 || v == '1') ? 1 : 0;
bool _bb(dynamic v) => v == true || v == 1 || v == '1';
List<dynamic> _decodeList(dynamic v) =>
    v == null ? const [] : (v is String ? (jsonDecode(v) as List) : (v as List));
Map<String, dynamic> _decodeMap(dynamic v) => v == null
    ? <String, dynamic>{}
    : (v is String
        ? (jsonDecode(v) as Map).cast<String, dynamic>()
        : (v as Map).cast<String, dynamic>());

/// A definite goal (Goal-Setting Theory + WOOP + ACT value anchor).
class Goal {
  final String id;
  final String wish;
  final String definiteStatement;
  final String? domain;
  final String? metric;
  final double? targetValue;
  final String? unit;
  final String? cadence;
  final String? valueAnchor;
  final List<dynamic> obstacles;
  final String stage; // goal_stage
  final String status; // goal_status
  final String startDate;
  final String? targetDate;
  final String updatedAt;

  Goal({
    required this.id,
    required this.wish,
    required this.definiteStatement,
    this.domain,
    this.metric,
    this.targetValue,
    this.unit,
    this.cadence,
    this.valueAnchor,
    this.obstacles = const [],
    this.stage = 'preparation',
    this.status = 'active',
    String? startDate,
    this.targetDate,
    String? updatedAt,
  })  : startDate = startDate ?? _today(),
        updatedAt = updatedAt ?? _nowIso();

  String get table => 'goals';

  Map<String, dynamic> toMap() => {
        'id': id,
        'wish': wish,
        'definite_statement': definiteStatement,
        'domain': domain,
        'metric': metric,
        'target_value': targetValue,
        'unit': unit,
        'cadence': cadence,
        'value_anchor': valueAnchor,
        'obstacles': jsonEncode(obstacles),
        'stage': stage,
        'status': status,
        'start_date': startDate,
        'target_date': targetDate,
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'wish': wish,
        'definite_statement': definiteStatement,
        'domain': domain,
        'metric': metric,
        'target_value': targetValue,
        'unit': unit,
        'cadence': cadence,
        'value_anchor': valueAnchor,
        'obstacles': obstacles,
        'stage': stage,
        'status': status,
        'start_date': startDate,
        'target_date': targetDate,
        'updated_at': updatedAt,
      };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'] as String,
        wish: m['wish'] as String,
        definiteStatement: m['definite_statement'] as String,
        domain: m['domain'] as String?,
        metric: m['metric'] as String?,
        targetValue: (m['target_value'] as num?)?.toDouble(),
        unit: m['unit'] as String?,
        cadence: m['cadence'] as String?,
        valueAnchor: m['value_anchor'] as String?,
        obstacles: _decodeList(m['obstacles']),
        stage: (m['stage'] as String?) ?? 'preparation',
        status: (m['status'] as String?) ?? 'active',
        startDate: m['start_date'] as String?,
        targetDate: m['target_date'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

/// A tiny, Fogg-sized if-then implementation intention toward a goal.
class GoalStep {
  final String id;
  final String goalId;
  final String title;
  final String? ifCue;
  final String? thenAction;
  final String? anchorRoutine;
  final String? bctId;
  final int orderIdx;
  final String status;
  final String updatedAt;

  GoalStep({
    required this.id,
    required this.goalId,
    required this.title,
    this.ifCue,
    this.thenAction,
    this.anchorRoutine,
    this.bctId,
    this.orderIdx = 0,
    this.status = 'active',
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'goal_steps';

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'title': title,
        'if_cue': ifCue,
        'then_action': thenAction,
        'anchor_routine': anchorRoutine,
        'bct_id': bctId,
        'order_idx': orderIdx,
        'status': status,
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        ...toMap(),
        'user_id': userId,
      };

  factory GoalStep.fromMap(Map<String, dynamic> m) => GoalStep(
        id: m['id'] as String,
        goalId: m['goal_id'] as String,
        title: m['title'] as String,
        ifCue: m['if_cue'] as String?,
        thenAction: m['then_action'] as String?,
        anchorRoutine: m['anchor_routine'] as String?,
        bctId: m['bct_id'] as String?,
        orderIdx: (m['order_idx'] as int?) ?? 0,
        status: (m['status'] as String?) ?? 'active',
        updatedAt: m['updated_at'] as String?,
      );
}

/// Daily adherence to a step (feeds automaticity + consistency).
class StepLog {
  final String id;
  final String stepId;
  final String day;
  final bool done;
  final String? note;
  final String updatedAt;

  StepLog({
    required this.id,
    required this.stepId,
    required this.day,
    this.done = true,
    this.note,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'step_logs';

  Map<String, dynamic> toMap() => {
        'id': id,
        'step_id': stepId,
        'day': day,
        'done': _b(done),
        'note': note,
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'step_id': stepId,
        'day': day,
        'done': done,
        'note': note,
        'updated_at': updatedAt,
      };

  factory StepLog.fromMap(Map<String, dynamic> m) => StepLog(
        id: m['id'] as String,
        stepId: m['step_id'] as String,
        day: m['day'] as String,
        done: _bb(m['done']),
        note: m['note'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

/// One adaptive check-in instance.
class BloomSession {
  final String id;
  final String day;
  final String mode;
  final String? summary;
  final int? mood;
  final String startedAt;
  final String? endedAt;
  final String updatedAt;

  BloomSession({
    required this.id,
    required this.day,
    this.mode = 'adaptive',
    this.summary,
    this.mood,
    String? startedAt,
    this.endedAt,
    String? updatedAt,
  })  : startedAt = startedAt ?? _nowIso(),
        updatedAt = updatedAt ?? _nowIso();

  String get table => 'sessions';

  Map<String, dynamic> toMap() => {
        'id': id,
        'day': day,
        'mode': mode,
        'summary': summary,
        'mood': mood,
        'started_at': startedAt,
        'ended_at': endedAt,
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        ...toMap(),
        'user_id': userId,
      };

  factory BloomSession.fromMap(Map<String, dynamic> m) => BloomSession(
        id: m['id'] as String,
        day: m['day'] as String,
        mode: (m['mode'] as String?) ?? 'adaptive',
        summary: m['summary'] as String?,
        mood: m['mood'] as int?,
        startedAt: m['started_at'] as String?,
        endedAt: m['ended_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

/// One calibrated question/answer turn (MI/OARS + Socratic trail).
class SessionTurn {
  final String id;
  final String sessionId;
  final String? qId;
  final String question;
  final String? answer;
  final String? comBFactor;
  final bool changeTalk;
  final int orderIdx;
  final String updatedAt;

  SessionTurn({
    required this.id,
    required this.sessionId,
    this.qId,
    required this.question,
    this.answer,
    this.comBFactor,
    this.changeTalk = false,
    this.orderIdx = 0,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'session_turns';

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'q_id': qId,
        'question': question,
        'answer': answer,
        'com_b_factor': comBFactor,
        'change_talk': _b(changeTalk),
        'order_idx': orderIdx,
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'session_id': sessionId,
        'q_id': qId,
        'question': question,
        'answer': answer,
        'com_b_factor': comBFactor,
        'change_talk': changeTalk,
        'order_idx': orderIdx,
        'updated_at': updatedAt,
      };

  factory SessionTurn.fromMap(Map<String, dynamic> m) => SessionTurn(
        id: m['id'] as String,
        sessionId: m['session_id'] as String,
        qId: m['q_id'] as String?,
        question: m['question'] as String,
        answer: m['answer'] as String?,
        comBFactor: m['com_b_factor'] as String?,
        changeTalk: _bb(m['change_talk']),
        orderIdx: (m['order_idx'] as int?) ?? 0,
        updatedAt: m['updated_at'] as String?,
      );
}

/// A validated wellbeing measure score (MBC/ROM).
class Measure {
  final String id;
  final String instrument; // who5 | phq9 | gad7 | custom
  final String day;
  final double? score;
  final Map<String, dynamic> items;
  final String updatedAt;

  Measure({
    required this.id,
    required this.instrument,
    required this.day,
    this.score,
    this.items = const {},
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'measures';

  Map<String, dynamic> toMap() => {
        'id': id,
        'instrument': instrument,
        'day': day,
        'score': score,
        'items': jsonEncode(items),
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'instrument': instrument,
        'day': day,
        'score': score,
        'items': items,
        'updated_at': updatedAt,
      };

  factory Measure.fromMap(Map<String, dynamic> m) => Measure(
        id: m['id'] as String,
        instrument: m['instrument'] as String,
        day: m['day'] as String,
        score: (m['score'] as num?)?.toDouble(),
        items: _decodeMap(m['items']),
        updatedAt: m['updated_at'] as String?,
      );
}

/// The ethical "push" — celebrate / nudge / replan / insight.
class Reinforcement {
  final String id;
  final String day;
  final String kind; // celebrate | nudge | replan | insight
  final String text;
  final String? goalId;
  final String? source; // ai | rules
  final String? deliveredAt;
  final String updatedAt;

  Reinforcement({
    required this.id,
    required this.day,
    required this.kind,
    required this.text,
    this.goalId,
    this.source,
    this.deliveredAt,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'reinforcements';

  Map<String, dynamic> toMap() => {
        'id': id,
        'day': day,
        'kind': kind,
        'text': text,
        'goal_id': goalId,
        'source': source,
        'delivered_at': deliveredAt,
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        ...toMap(),
        'user_id': userId,
      };

  factory Reinforcement.fromMap(Map<String, dynamic> m) => Reinforcement(
        id: m['id'] as String,
        day: m['day'] as String,
        kind: m['kind'] as String,
        text: m['text'] as String,
        goalId: m['goal_id'] as String?,
        source: m['source'] as String?,
        deliveredAt: m['delivered_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

/// Longitudinal "pocket therapist" memory (one row per user).
class MemoryProfile {
  final String id;
  final Map<String, dynamic> summary;
  final List<dynamic> values;
  final List<dynamic> patterns;
  final String updatedAt;

  MemoryProfile({
    required this.id,
    this.summary = const {},
    this.values = const [],
    this.patterns = const [],
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'memory_profile';

  Map<String, dynamic> toMap() => {
        'id': id,
        'summary': jsonEncode(summary),
        'core_values': jsonEncode(values), // 'values' is a reserved SQL word
        'patterns': jsonEncode(patterns),
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'summary': summary,
        'core_values': values,
        'patterns': patterns,
        'updated_at': updatedAt,
      };

  factory MemoryProfile.fromMap(Map<String, dynamic> m) => MemoryProfile(
        id: m['id'] as String,
        summary: _decodeMap(m['summary']),
        values: _decodeList(m['core_values'] ?? m['values']),
        patterns: _decodeList(m['patterns']),
        updatedAt: m['updated_at'] as String?,
      );
}

/// Granular, revocable consent record.
class Consent {
  final String id;
  final String scope; // ai | money | location | screen | measures
  final bool granted;
  final String? grantedAt;
  final String? revokedAt;
  final String updatedAt;

  Consent({
    required this.id,
    required this.scope,
    this.granted = false,
    this.grantedAt,
    this.revokedAt,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'consents';

  Map<String, dynamic> toMap() => {
        'id': id,
        'scope': scope,
        'granted': _b(granted),
        'granted_at': grantedAt,
        'revoked_at': revokedAt,
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'scope': scope,
        'granted': granted,
        'granted_at': grantedAt,
        'revoked_at': revokedAt,
        'updated_at': updatedAt,
      };

  factory Consent.fromMap(Map<String, dynamic> m) => Consent(
        id: m['id'] as String,
        scope: m['scope'] as String,
        granted: _bb(m['granted']),
        grantedAt: m['granted_at'] as String?,
        revokedAt: m['revoked_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

/// A tunable, skippable reminder (no streaks, no coercion).
class ReminderPref {
  final String id;
  final String kind; // daily_session | step | measure
  final String? schedule; // HH:mm
  final bool enabled;
  final String? lastFiredAt;
  final String updatedAt;

  ReminderPref({
    required this.id,
    required this.kind,
    this.schedule,
    this.enabled = true,
    this.lastFiredAt,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'reminders';

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind,
        'schedule': schedule,
        'enabled': _b(enabled),
        'last_fired_at': lastFiredAt,
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'kind': kind,
        'schedule': schedule,
        'enabled': enabled,
        'last_fired_at': lastFiredAt,
        'updated_at': updatedAt,
      };

  factory ReminderPref.fromMap(Map<String, dynamic> m) => ReminderPref(
        id: m['id'] as String,
        kind: m['kind'] as String,
        schedule: m['schedule'] as String?,
        enabled: _bb(m['enabled']),
        lastFiredAt: m['last_fired_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

/// An opt-in passive signal (money/location/screen).
class PassiveSignal {
  final String id;
  final String source; // money | location | screen
  final String? kind;
  final Map<String, dynamic> value;
  final String observedAt;
  final bool reconciled;
  final String updatedAt;

  PassiveSignal({
    required this.id,
    required this.source,
    this.kind,
    this.value = const {},
    String? observedAt,
    this.reconciled = false,
    String? updatedAt,
  })  : observedAt = observedAt ?? _nowIso(),
        updatedAt = updatedAt ?? _nowIso();

  String get table => 'passive_signals';

  Map<String, dynamic> toMap() => {
        'id': id,
        'source': source,
        'kind': kind,
        'value': jsonEncode(value),
        'observed_at': observedAt,
        'reconciled': _b(reconciled),
        'updated_at': updatedAt,
      };

  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'source': source,
        'kind': kind,
        'value': value,
        'observed_at': observedAt,
        'reconciled': reconciled,
        'updated_at': updatedAt,
      };

  factory PassiveSignal.fromMap(Map<String, dynamic> m) => PassiveSignal(
        id: m['id'] as String,
        source: m['source'] as String,
        kind: m['kind'] as String?,
        value: _decodeMap(m['value']),
        observedAt: m['observed_at'] as String?,
        reconciled: _bb(m['reconciled']),
        updatedAt: m['updated_at'] as String?,
      );
}
