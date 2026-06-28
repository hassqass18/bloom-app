import '../../core/ai/ai_client.dart';
import '../../core/config/env.dart';
import '../../core/supabase/supabase_service.dart';
import '../../data/models/models2.dart';
import 'question_bank.dart';

/// The next calibrated question + whether the session should wrap up.
class NextQuestion {
  final String qId;
  final String question;
  final String comBFactor;
  final bool isFinal;
  const NextQuestion(this.qId, this.question, this.comBFactor, this.isFinal);
}

/// Chooses the next question for the adaptive daily check-in.
/// Online: calls the `session-next` Edge Function (MI/OARS + CAT-style selection).
/// Offline / AI off: walks the local [kQuestionBank] in a sensible order.
class SessionEngine {
  static const _maxTurns = 6;

  Future<NextQuestion> next({
    required List<Goal> goals,
    required List<SessionTurn> turns,
    MemoryProfile? memory,
    String stage = 'action',
  }) async {
    final body = {
      'goals': goals.map((g) => g.definiteStatement).toList(),
      'turns': turns.map((t) => {'q': t.question, 'a': t.answer}).toList(),
      'memory': memory?.summary,
      'stage': stage,
    };
    // Primary: direct AI brain (Vercel/Claude) — adaptive + gender-aware.
    final ai = await AiClient.call('session-next', body);
    final aq = ai?['question'] as String?;
    if (aq != null && aq.trim().isNotEmpty) {
      return NextQuestion(
        (ai!['q_id'] as String?) ?? 'ai',
        aq.trim(),
        (ai['com_b_factor'] as String?) ?? 'reflection',
        (ai['is_final'] as bool?) ?? (turns.length >= _maxTurns - 1),
      );
    }
    // Secondary: Supabase functions, if deployed + signed in.
    if (Env.hasCloud && SupabaseService.isSignedIn) {
      try {
        final res =
            await SupabaseService.client.functions.invoke('session-next', body: body);
        final data = res.data as Map?;
        final q = data?['question'] as String?;
        if (q != null && q.trim().isNotEmpty) {
          return NextQuestion(
            (data?['q_id'] as String?) ?? 'ai',
            q.trim(),
            (data?['com_b_factor'] as String?) ?? 'reflection',
            (data?['is_final'] as bool?) ?? (turns.length >= _maxTurns - 1),
          );
        }
      } catch (_) {
        // fall through to offline bank
      }
    }
    return _offline(turns.length);
  }

  NextQuestion _offline(int asked) {
    final i = asked.clamp(0, kQuestionBank.length - 1);
    final q = kQuestionBank[i];
    final isFinal = asked >= kQuestionBank.length - 1 || asked >= _maxTurns - 1;
    return NextQuestion(q.qId, q.question, q.comBFactor, isFinal);
  }

  /// Lightweight change-talk heuristic (MI): does the answer express desire,
  /// ability, reason, need, or commitment to change?
  bool looksLikeChangeTalk(String? answer) {
    if (answer == null) return false;
    final a = answer.toLowerCase();
    const cues = [
      'i want', 'i will', 'i can', 'i need', 'i should', "i'm going to",
      'i am going to', 'i could', 'i hope', 'i plan', 'i decided', 'i have to',
    ];
    return cues.any(a.contains);
  }
}
