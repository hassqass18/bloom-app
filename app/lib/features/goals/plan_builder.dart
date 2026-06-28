import '../../core/ai/ai_client.dart';
import '../../core/config/env.dart';
import '../../core/supabase/supabase_service.dart';

/// A draft tiny if-then step (implementation intention).
class StepDraft {
  String title;
  String ifCue;
  String thenAction;
  String anchorRoutine;
  String bctId;
  StepDraft({
    this.title = '',
    this.ifCue = '',
    this.thenAction = '',
    this.anchorRoutine = '',
    this.bctId = '1.4_action_planning',
  });
}

/// A draft definite goal produced from a broad wish.
class BuiltPlan {
  String definiteStatement;
  String domain;
  String metric;
  double? targetValue;
  String unit;
  String cadence;
  String valueAnchor;
  List<String> obstacles;
  List<StepDraft> steps;
  BuiltPlan({
    required this.definiteStatement,
    this.domain = 'growth',
    this.metric = '',
    this.targetValue,
    this.unit = '',
    this.cadence = 'daily',
    this.valueAnchor = '',
    this.obstacles = const [],
    this.steps = const [],
  });
}

/// Turns a broad wish into a definite goal + tiny steps.
/// Online: calls `plan-build` (Goal-Setting Theory + WOOP + Tiny Habits).
/// Offline: a sensible deterministic template the user can edit.
class PlanBuilder {
  Future<BuiltPlan> build(String wish, {Map<String, dynamic>? context}) async {
    // Primary: the direct AI brain (Vercel/Claude) — builds tasks from THIS wish.
    final ai = await AiClient.call('plan-build', {'wish': wish, 'context': context});
    if (ai != null && ai['definite_statement'] != null) return _fromMap(ai, wish);
    // Secondary: Supabase functions, if deployed + signed in.
    if (Env.hasCloud && SupabaseService.isSignedIn) {
      try {
        final res = await SupabaseService.client.functions.invoke(
          'plan-build',
          body: {'wish': wish, 'context': context},
        );
        final d = res.data as Map?;
        if (d != null && d['definite_statement'] != null) {
          return _fromMap(Map<String, dynamic>.from(d), wish);
        }
      } catch (_) {
        // fall through to offline template
      }
    }
    return _template(wish);
  }

  BuiltPlan _fromMap(Map<String, dynamic> d, String wish) {
    final steps = ((d['steps'] as List?) ?? const [])
        .map((s) => StepDraft(
              title: (s['title'] ?? '').toString(),
              ifCue: (s['if_cue'] ?? '').toString(),
              thenAction: (s['then_action'] ?? '').toString(),
              anchorRoutine: (s['anchor_routine'] ?? '').toString(),
              bctId: (s['bct_id'] ?? '1.4_action_planning').toString(),
            ))
        .toList();
    return BuiltPlan(
      definiteStatement: (d['definite_statement'] ?? wish).toString(),
      domain: (d['domain'] ?? 'growth').toString(),
      metric: (d['metric'] ?? '').toString(),
      targetValue: (d['target_value'] as num?)?.toDouble(),
      unit: (d['unit'] ?? '').toString(),
      cadence: (d['cadence'] ?? 'daily').toString(),
      valueAnchor: (d['value_anchor'] ?? '').toString(),
      obstacles: ((d['obstacles'] as List?) ?? const []).map((e) => e.toString()).toList(),
      steps: steps.isEmpty ? _template(wish).steps : steps,
    );
  }

  BuiltPlan _template(String wish) => BuiltPlan(
        definiteStatement: 'Make steady, measurable progress on: $wish',
        domain: 'growth',
        metric: 'days I take one small action',
        targetValue: 5,
        unit: 'days/week',
        cadence: 'daily',
        valueAnchor: 'the person I want to become',
        obstacles: ['forgetting', 'low-energy days'],
        steps: [
          StepDraft(
            title: 'One tiny action each day',
            ifCue: 'After my morning tea',
            thenAction: 'I do one small thing toward this goal',
            anchorRoutine: 'morning tea',
          ),
        ],
      );
}
