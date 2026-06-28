import 'dart:convert';

/// Domain models for Bloom's "everything" life-log.
/// Each maps to a local sqflite row and a Supabase remote row.
/// `day` is an ISO date string (yyyy-MM-dd). Timestamps are ISO-8601 UTC.

String today() => DateTime.now().toIso8601String().substring(0, 10);
String _nowIso() => DateTime.now().toUtc().toIso8601String();

/// One soft container per calendar day.
class DayLog {
  final String day;
  final int? mood; // 1..5
  final String? moodNote;
  final String updatedAt;

  DayLog({required this.day, this.mood, this.moodNote, String? updatedAt})
      : updatedAt = updatedAt ?? _nowIso();

  Map<String, dynamic> toMap() => {
        'day': day,
        'mood': mood,
        'mood_note': moodNote,
        'updated_at': updatedAt,
      };

  /// Payload sent to Supabase (user_id is filled server-side via default auth.uid()).
  Map<String, dynamic> toRemote(String userId) => {
        'user_id': userId,
        'day': day,
        'mood': mood,
        'mood_note': moodNote,
        'updated_at': updatedAt,
      };

  factory DayLog.fromMap(Map<String, dynamic> m) => DayLog(
        day: m['day'] as String,
        mood: m['mood'] as int?,
        moodNote: m['mood_note'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

/// Base for the id'd, soft-deletable domain rows.
abstract class Entry {
  String get id;
  String get day;
  String get table;
  Map<String, dynamic> toMap();
  Map<String, dynamic> toRemote(String userId);
}

class JournalEntry implements Entry {
  @override
  final String id;
  @override
  final String day;
  final String kind; // read|watched|word|proud|improve|thoughts
  final Map<String, dynamic> payload;
  final int words;
  final String updatedAt;

  JournalEntry({
    required this.id,
    required this.day,
    required this.kind,
    required this.payload,
    this.words = 0,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  @override
  String get table => 'journal_entries';

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'day': day,
        'kind': kind,
        'payload': jsonEncode(payload),
        'words': words,
        'updated_at': updatedAt,
      };

  @override
  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'day': day,
        'kind': kind,
        'payload': payload,
        'words': words,
        'updated_at': updatedAt,
      };

  factory JournalEntry.fromMap(Map<String, dynamic> m) => JournalEntry(
        id: m['id'] as String,
        day: m['day'] as String,
        kind: m['kind'] as String,
        payload: jsonDecode(m['payload'] as String) as Map<String, dynamic>,
        words: (m['words'] as int?) ?? 0,
        updatedAt: m['updated_at'] as String?,
      );
}

class Thought implements Entry {
  @override
  final String id;
  @override
  final String day;
  final String body;
  final String updatedAt;

  Thought({required this.id, required this.day, required this.body, String? updatedAt})
      : updatedAt = updatedAt ?? _nowIso();

  @override
  String get table => 'thoughts';

  @override
  Map<String, dynamic> toMap() =>
      {'id': id, 'day': day, 'body': body, 'updated_at': updatedAt};

  @override
  Map<String, dynamic> toRemote(String userId) =>
      {'id': id, 'user_id': userId, 'day': day, 'body': body, 'updated_at': updatedAt};

  factory Thought.fromMap(Map<String, dynamic> m) => Thought(
        id: m['id'] as String,
        day: m['day'] as String,
        body: m['body'] as String,
        updatedAt: m['updated_at'] as String?,
      );
}

class Emotion implements Entry {
  @override
  final String id;
  @override
  final String day;
  final String emotion;
  final int? valence; // -2..2
  final int? energy; // -2..2
  final String? note;
  final String updatedAt;

  Emotion({
    required this.id,
    required this.day,
    required this.emotion,
    this.valence,
    this.energy,
    this.note,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  @override
  String get table => 'emotions';

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'day': day,
        'emotion': emotion,
        'valence': valence,
        'energy': energy,
        'note': note,
        'updated_at': updatedAt,
      };

  @override
  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'day': day,
        'emotion': emotion,
        'valence': valence,
        'energy': energy,
        'note': note,
        'updated_at': updatedAt,
      };

  factory Emotion.fromMap(Map<String, dynamic> m) => Emotion(
        id: m['id'] as String,
        day: m['day'] as String,
        emotion: m['emotion'] as String,
        valence: m['valence'] as int?,
        energy: m['energy'] as int?,
        note: m['note'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

class Activity implements Entry {
  @override
  final String id;
  @override
  final String day;
  final String title;
  final List<String> tags;
  final int? durationMin;
  final String? note;
  final String updatedAt;

  Activity({
    required this.id,
    required this.day,
    required this.title,
    this.tags = const [],
    this.durationMin,
    this.note,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  @override
  String get table => 'activities';

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'day': day,
        'title': title,
        'tags': jsonEncode(tags),
        'duration_min': durationMin,
        'note': note,
        'updated_at': updatedAt,
      };

  @override
  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'day': day,
        'title': title,
        'tags': tags,
        'duration_min': durationMin,
        'note': note,
        'updated_at': updatedAt,
      };

  factory Activity.fromMap(Map<String, dynamic> m) => Activity(
        id: m['id'] as String,
        day: m['day'] as String,
        title: m['title'] as String,
        tags: (jsonDecode(m['tags'] as String) as List).cast<String>(),
        durationMin: m['duration_min'] as int?,
        note: m['note'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

class MoneyEntry implements Entry {
  @override
  final String id;
  @override
  final String day;
  final String direction; // spent|earned
  final double amount;
  final String currency;
  final String? category;
  final String? note;
  final String updatedAt;

  MoneyEntry({
    required this.id,
    required this.day,
    required this.direction,
    required this.amount,
    this.currency = 'KES',
    this.category,
    this.note,
    String? updatedAt,
  }) : updatedAt = updatedAt ?? _nowIso();

  @override
  String get table => 'money_entries';

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'day': day,
        'direction': direction,
        'amount': amount,
        'currency': currency,
        'category': category,
        'note': note,
        'updated_at': updatedAt,
      };

  @override
  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'day': day,
        'direction': direction,
        'amount': amount,
        'currency': currency,
        'category': category,
        'note': note,
        'updated_at': updatedAt,
      };

  factory MoneyEntry.fromMap(Map<String, dynamic> m) => MoneyEntry(
        id: m['id'] as String,
        day: m['day'] as String,
        direction: m['direction'] as String,
        amount: (m['amount'] as num).toDouble(),
        currency: m['currency'] as String? ?? 'KES',
        category: m['category'] as String?,
        note: m['note'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}
