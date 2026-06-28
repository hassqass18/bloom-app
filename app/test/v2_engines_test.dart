import 'package:bloom/data/models/models2.dart';
import 'package:bloom/features/goals/plan_builder.dart';
import 'package:bloom/features/session/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionEngine (offline)', () {
    final engine = SessionEngine();

    test('detects change talk', () {
      expect(engine.looksLikeChangeTalk('I want to save more'), isTrue);
      expect(engine.looksLikeChangeTalk('I will start tomorrow'), isTrue);
      expect(engine.looksLikeChangeTalk('it was an ok day'), isFalse);
      expect(engine.looksLikeChangeTalk(null), isFalse);
    });

    test('offline questions are ordered and terminate', () async {
      final q0 = await engine.next(goals: const [], turns: const []);
      expect(q0.question, isNotEmpty);
      expect(q0.isFinal, isFalse);

      // Simulate having asked many turns -> should signal final.
      final manyTurns = List.generate(
        6,
        (i) => SessionTurn(id: '$i', sessionId: 's', question: 'q$i', orderIdx: i),
      );
      final qN = await engine.next(goals: const [], turns: manyTurns);
      expect(qN.isFinal, isTrue);
    });
  });

  group('PlanBuilder (offline template)', () {
    test('builds a definite plan with at least one tiny step', () async {
      final plan = await PlanBuilder().build('I want to save more money');
      expect(plan.definiteStatement, isNotEmpty);
      expect(plan.steps, isNotEmpty);
      expect(plan.steps.first.ifCue, isNotEmpty);
      expect(plan.steps.first.thenAction, isNotEmpty);
    });
  });

  group('Model round-trips', () {
    test('Goal toMap/fromMap preserves fields', () {
      final g = Goal(
        id: 'g1',
        wish: 'save money',
        definiteStatement: 'Save 30% of income monthly',
        domain: 'money',
        targetValue: 30,
        unit: '%',
        cadence: 'monthly',
        valueAnchor: 'a saver',
        obstacles: const ['impulse buys'],
        stage: 'preparation',
      );
      final back = Goal.fromMap(g.toMap());
      expect(back.definiteStatement, g.definiteStatement);
      expect(back.targetValue, 30);
      expect(back.obstacles, contains('impulse buys'));
    });

    test('StepLog bool survives local int encoding', () {
      final l = StepLog(id: 'l1', stepId: 's1', day: '2026-06-26', done: true);
      final back = StepLog.fromMap(l.toMap());
      expect(back.done, isTrue);
      expect(l.toMap()['done'], 1);
    });

    test('Measure json items round-trip', () {
      final m = Measure(
        id: 'm1',
        instrument: 'who5',
        day: '2026-06-26',
        score: 72,
        items: const {'q1': 4, 'q2': 3},
      );
      final back = Measure.fromMap(m.toMap());
      expect(back.score, 72);
      expect(back.items['q1'], 4);
    });
  });
}
