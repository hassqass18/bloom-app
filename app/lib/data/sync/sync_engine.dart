import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/supabase/supabase_service.dart';
import '../local/local_db.dart';

/// Two-way sync between the local sqflite store and Supabase.
///  * push: drains the outbound sync_queue (last-write-wins upserts + soft deletes)
///  * pull: fetches rows changed since the last watermark and writes them locally
/// Fail-safe: failures stay queued / retried. Sync never blocks capture.
///
/// v2: handles all behavior-change tables generically using LocalDb's
/// json/bool column metadata (TEXT⇄object, INTEGER 0/1 ⇄ bool).
class SyncEngine {
  SyncEngine._();
  static final SyncEngine instance = SyncEngine._();

  final LocalDb _db = LocalDb.instance;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _running = false;

  static const _watermarkKey = 'pull_watermark';

  void start() {
    unawaited(sync());
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) unawaited(sync());
    });
  }

  void dispose() => _connSub?.cancel();

  Future<void> sync() async {
    if (_running) return;
    if (!SupabaseService.isSignedIn || SupabaseService.userId == null) return;
    _running = true;
    try {
      await _push();
      await _pull();
    } finally {
      _running = false;
    }
  }

  /// Kept for callers that just want to flush outbound writes.
  Future<void> pushPending() => sync();

  Future<void> _push() async {
    final userId = SupabaseService.userId!;
    final client = SupabaseService.client;
    final ops = await _db.pendingOps();
    for (final op in ops) {
      final seq = op['seq'] as int;
      final tbl = op['tbl'] as String;
      final kind = op['op'] as String;
      final rowId = op['row_id'] as String?;
      final payload = jsonDecode(op['payload'] as String) as Map<String, dynamic>;
      try {
        if (kind == 'delete') {
          await client.from(tbl).update({
            'deleted_at': payload['deleted_at'],
            'updated_at': payload['deleted_at'],
          }).eq('id', rowId as Object);
        } else {
          final remote = _toRemote(tbl, payload, userId);
          if (tbl == 'days') {
            await client.from(tbl).upsert(remote, onConflict: 'user_id,day');
          } else {
            await client.from(tbl).upsert(remote);
          }
        }
        await _db.clearOp(seq);
      } catch (e) {
        debugPrint('sync push $seq ($tbl/$kind) failed: $e');
        break; // preserve order; retry later
      }
    }
  }

  Future<void> _pull() async {
    final client = SupabaseService.client;
    final since = await _db.getMeta(_watermarkKey) ?? '1970-01-01T00:00:00Z';
    var maxSeen = since;

    Future<void> pullTable(String tbl, Map<String, dynamic> Function(Map<String, dynamic>) toLocal) async {
      final rows = await client
          .from(tbl)
          .select()
          .gt('updated_at', since)
          .order('updated_at') as List;
      for (final raw in rows) {
        final m = Map<String, dynamic>.from(raw as Map);
        await _db.putLocal(tbl, toLocal(m));
        final u = m['updated_at'] as String?;
        if (u != null && u.compareTo(maxSeen) > 0) maxSeen = u;
      }
    }

    try {
      // days is special (no id, no soft-delete shape).
      await pullTable('days', (m) => {
            'day': m['day'], 'mood': m['mood'], 'mood_note': m['mood_note'],
            'updated_at': m['updated_at'],
          });
      // Everything else flows through the generic remote→local transform.
      for (final tbl in LocalDb.syncTables) {
        await pullTable(tbl, (m) => _toLocal(tbl, m));
      }
      if (maxSeen != since) await _db.setMeta(_watermarkKey, maxSeen);
    } catch (e) {
      debugPrint('sync pull failed: $e');
    }
  }

  /// Local row (TEXT json, INT bools) → remote row (json objects, bools).
  Map<String, dynamic> _toRemote(String tbl, Map<String, dynamic> m, String userId) {
    final out = Map<String, dynamic>.from(m)..['user_id'] = userId;
    for (final c in LocalDb.jsonColumns[tbl] ?? const <String>[]) {
      if (out[c] is String) out[c] = jsonDecode(out[c] as String);
    }
    for (final c in LocalDb.boolColumns[tbl] ?? const <String>[]) {
      if (out[c] != null) out[c] = (out[c] == 1 || out[c] == true);
    }
    out.remove('deleted_at');
    return out;
  }

  /// Remote row (json objects, bools) → local row (TEXT json, INT bools).
  Map<String, dynamic> _toLocal(String tbl, Map<String, dynamic> m) {
    final out = Map<String, dynamic>.from(m)..remove('user_id')..remove('created_at');
    for (final c in LocalDb.jsonColumns[tbl] ?? const <String>[]) {
      final v = out[c];
      out[c] = v == null ? null : (v is String ? v : jsonEncode(v));
    }
    for (final c in LocalDb.boolColumns[tbl] ?? const <String>[]) {
      if (out[c] != null) out[c] = (out[c] == true || out[c] == 1) ? 1 : 0;
    }
    return out;
  }
}
