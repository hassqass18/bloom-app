// Bloom v3 holistic-logging models: prayer/meditation/reflection, fitness,
// nutrition, journal, and user-chosen tracked areas. Local sqflite stores
// booleans as INTEGER 0/1; toRemote uses real bools. NO reserved-word columns.

String _nowIso() => DateTime.now().toUtc().toIso8601String();

int _b(dynamic v) => (v == true || v == 1 || v == '1') ? 1 : 0;
bool _bb(dynamic v) => v == true || v == 1 || v == '1';

class PracticeLog {
  final String id;
  final String day;
  final String kind; // prayer | meditation | reflection
  final bool done;
  final String? note;
  final String updatedAt;
  PracticeLog({
    required this.id,
    required this.day,
    required this.kind,
    this.done = false,
    this.note,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'practice_logs';
  Map<String, dynamic> toMap() => {
        'id': id, 'day': day, 'kind': kind, 'done': _b(done),
        'note': note, 'updated_at': updatedAt,
      };
  Map<String, dynamic> toRemote(String userId) => {
        'id': id, 'user_id': userId, 'day': day, 'kind': kind,
        'done': done, 'note': note, 'updated_at': updatedAt,
      };
  factory PracticeLog.fromMap(Map<String, dynamic> m) => PracticeLog(
        id: m['id'] as String, day: m['day'] as String, kind: m['kind'] as String,
        done: _bb(m['done']), note: m['note'] as String?, updatedAt: m['updated_at'] as String?,
      );
}

class FitnessLog {
  final String id;
  final String day;
  final String activity;
  final int? durationMin;
  final String? intensity;
  final String? note;
  final String updatedAt;
  FitnessLog({
    required this.id,
    required this.day,
    required this.activity,
    this.durationMin,
    this.intensity,
    this.note,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'fitness_logs';
  Map<String, dynamic> toMap() => {
        'id': id, 'day': day, 'activity': activity, 'duration_min': durationMin,
        'intensity': intensity, 'note': note, 'updated_at': updatedAt,
      };
  Map<String, dynamic> toRemote(String userId) => {...toMap(), 'user_id': userId};
  factory FitnessLog.fromMap(Map<String, dynamic> m) => FitnessLog(
        id: m['id'] as String, day: m['day'] as String, activity: m['activity'] as String,
        durationMin: m['duration_min'] as int?, intensity: m['intensity'] as String?,
        note: m['note'] as String?, updatedAt: m['updated_at'] as String?,
      );
}

class NutritionLog {
  final String id;
  final String day;
  final String kind; // meal | water | snack
  final String? label;
  final double? kcal;
  final int? waterMl;
  final String? note;
  final String updatedAt;
  NutritionLog({
    required this.id,
    required this.day,
    required this.kind,
    this.label,
    this.kcal,
    this.waterMl,
    this.note,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'nutrition_logs';
  Map<String, dynamic> toMap() => {
        'id': id, 'day': day, 'kind': kind, 'label': label, 'kcal': kcal,
        'water_ml': waterMl, 'note': note, 'updated_at': updatedAt,
      };
  Map<String, dynamic> toRemote(String userId) => {...toMap(), 'user_id': userId};
  factory NutritionLog.fromMap(Map<String, dynamic> m) => NutritionLog(
        id: m['id'] as String, day: m['day'] as String, kind: m['kind'] as String,
        label: m['label'] as String?, kcal: (m['kcal'] as num?)?.toDouble(),
        waterMl: m['water_ml'] as int?, note: m['note'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

class JournalEntryV3 {
  final String id;
  final String day;
  final String body;
  final String mode; // manual | guided
  final String? source;
  final String updatedAt;
  JournalEntryV3({
    required this.id,
    required this.day,
    required this.body,
    this.mode = 'manual',
    this.source,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'journal';
  Map<String, dynamic> toMap() => {
        'id': id, 'day': day, 'body': body, 'mode': mode,
        'source': source, 'updated_at': updatedAt,
      };
  Map<String, dynamic> toRemote(String userId) => {...toMap(), 'user_id': userId};
  factory JournalEntryV3.fromMap(Map<String, dynamic> m) => JournalEntryV3(
        id: m['id'] as String, day: m['day'] as String, body: m['body'] as String,
        mode: (m['mode'] as String?) ?? 'manual', source: m['source'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

class TrackedArea {
  final String id;
  final String label;
  final String? domain;
  final double? target;
  final String? unit;
  final String? cadence;
  final String updatedAt;
  TrackedArea({
    required this.id,
    required this.label,
    this.domain,
    this.target,
    this.unit,
    this.cadence,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  String get table => 'tracked_areas';
  Map<String, dynamic> toMap() => {
        'id': id, 'label': label, 'domain': domain, 'target': target,
        'unit': unit, 'cadence': cadence, 'updated_at': updatedAt,
      };
  Map<String, dynamic> toRemote(String userId) => {...toMap(), 'user_id': userId};
  factory TrackedArea.fromMap(Map<String, dynamic> m) => TrackedArea(
        id: m['id'] as String, label: m['label'] as String, domain: m['domain'] as String?,
        target: (m['target'] as num?)?.toDouble(), unit: m['unit'] as String?,
        cadence: m['cadence'] as String?, updatedAt: m['updated_at'] as String?,
      );
}
