import '../../core/ai/ai_client.dart';
import '../../core/config/env.dart';
import '../../core/supabase/supabase_service.dart';

class ReinforceResult {
  final String kind; // celebrate | nudge | replan | insight
  final String text;
  const ReinforceResult(this.kind, this.text);
}

/// The ethical "push" (SDT + non-coercive design): celebrate real progress,
/// treat lapses as data. Online uses `reinforce`; offline uses warm rules.
class ReinforcementEngine {
  Future<ReinforceResult> generate({
    required Map<String, dynamic> progress,
    List<Map<String, dynamic>> logs = const [],
    String stage = 'action',
  }) async {
    final body = {'logs': logs, 'progress': progress, 'stage': stage};
    final ai = await AiClient.call('reinforce', body);
    if (ai != null && ai['text'] != null) {
      return ReinforceResult((ai['kind'] as String?) ?? 'celebrate', ai['text'].toString());
    }
    if (Env.hasCloud && SupabaseService.isSignedIn) {
      try {
        final res = await SupabaseService.client.functions.invoke('reinforce', body: body);
        final d = res.data as Map?;
        if (d != null && d['text'] != null) {
          return ReinforceResult(
              (d['kind'] as String?) ?? 'celebrate', d['text'].toString());
        }
      } catch (_) {
        // fall through
      }
    }
    return _offline(progress);
  }

  ReinforceResult _offline(Map<String, dynamic> progress) {
    final done = (progress['doneToday'] as int?) ?? 0;
    final rate = (progress['consistency'] as num?)?.toDouble() ?? 0;
    if (done > 0 && rate >= 0.6) {
      return const ReinforceResult('celebrate',
          "You're showing up consistently — your habit is quietly setting. Another vote for who you're becoming. 🌱");
    }
    if (done > 0) {
      return const ReinforceResult('celebrate',
          "You did it today. That single step counts more than you think. 🌸");
    }
    return const ReinforceResult('replan',
        "Today was a soft day, and that's okay — no streak to lose here. What's the smallest possible step for tomorrow? 💜");
  }
}
