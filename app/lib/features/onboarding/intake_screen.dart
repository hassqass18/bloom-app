import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/safety/crisis.dart';
import '../../core/theme/bloom_theme.dart';
import '../../core/voice/cloud_voice.dart';
import '../../core/voice/voice_conversation.dart';
import '../../core/util/name_gender.dart';
import '../../core/widgets/ambient_background.dart';
import '../../data/local/local_db.dart';
import '../../data/models/models.dart' show today;
import '../../data/models/models2.dart';
import '../../data/models/models3.dart';
import '../../providers.dart';
import '../goals/plan_builder.dart';
import '../voice/voice_orb.dart';
import 'intake_questions.dart';

/// The complete, therapist-style first session. Bloom speaks, listens, and at the
/// end synthesizes a foundational MemoryProfile + the user's first goal. This is
/// the foundation every future interaction is built on.
class IntakeScreen extends ConsumerStatefulWidget {
  const IntakeScreen({super.key});

  @override
  ConsumerState<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends ConsumerState<IntakeScreen> {
  final _vc = VoiceConversation(cloud: defaultCloudVoice());
  final _uuid = const Uuid();
  final _text = TextEditingController();

  final Map<String, String> _answers = {};
  bool _started = false;
  bool _finished = false;
  bool _forceText = false;
  bool _awaitingText = false;
  Completer<String>? _typed;
  String _caption = '';

  @override
  void initState() {
    super.initState();
    // Bloom starts speaking the moment the app opens — no tap required.
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _vc.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    if (_started) return;
    debugPrint('[intake] begin');
    setState(() => _started = true);
    await _vc.init();
    if (!_vc.sttAvailable) _forceText = true;
    debugPrint('[intake] init complete, starting run');
    await _run();
  }

  Future<void> _run() async {
    await _say(
        "Thank you for being here. I'm Bloom. I'd like to understand you — who you "
        "are, where you are right now, and what you'd like to change. Take your time.");
    for (final step in kIntakeScript) {
      if (!mounted) return;
      await _say(step.prompt);
      final ans = await _getAnswer(step.hint);
      if (!mounted) return;
      if (Crisis.looksLikeCrisis(ans)) await Crisis.show(context);
      _answers[step.id] = ans.trim();
    }
    await _synthesize();
  }

  Future<void> _synthesize() async {
    final repo = ref.read(entriesRepositoryProvider);
    final name = _clean(_answers['name'], fallback: 'friend');
    final value = _answers['value'] ?? '';
    final aspiration = _answers['aspiration'] ?? '';
    final readiness = (_answers['readiness'] ?? '').toLowerCase();
    final stage = readiness.contains('act') || readiness.contains('ready')
        ? 'preparation'
        : (readiness.contains('explor') ? 'contemplation' : 'preparation');

    // 1) Foundational longitudinal memory — the bedrock for every interaction.
    final gender = guessGender(name); // soft hint so Bloom adapts for men & women
    await repo.saveMemory(MemoryProfile(
      id: _uuid.v4(),
      summary: {
        'who': '$name — ${_answers['life'] ?? ''}'.trim(),
        'where': 'Feeling: ${_answers['feeling'] ?? ''}. '
            'Hardest right now: ${_answers['hardest'] ?? ''}.',
        'goals': aspiration,
        'readiness': readiness,
        if (gender != null) 'gender': gender,
      },
      values: [if (value.isNotEmpty) value],
      patterns: const [],
    ));
    await LocalDb.instance.setMeta('display_name', name);

    // 2) Seed an identity from what they value (ACT identity anchor).
    if (value.isNotEmpty) {
      await repo.addIdentity(_uuid.v4(), _short(value), '🌱');
    }

    // 3) Turn their aspiration into a first definite goal + tiny steps.
    if (aspiration.isNotEmpty) {
      try {
        final plan = await PlanBuilder().build(aspiration, context: {'name': name});
        final goalId = _uuid.v4();
        await repo.saveGoal(Goal(
          id: goalId,
          wish: aspiration,
          definiteStatement: plan.definiteStatement,
          domain: plan.domain,
          metric: plan.metric,
          targetValue: plan.targetValue,
          unit: plan.unit,
          cadence: plan.cadence,
          valueAnchor: value.isNotEmpty ? _short(value) : plan.valueAnchor,
          obstacles: plan.obstacles,
          stage: stage,
        ));
        for (var i = 0; i < plan.steps.length; i++) {
          final s = plan.steps[i];
          await repo.saveStep(GoalStep(
            id: _uuid.v4(),
            goalId: goalId,
            title: s.title,
            ifCue: s.ifCue,
            thenAction: s.thenAction,
            anchorRoutine: s.anchorRoutine,
            bctId: s.bctId,
            orderIdx: i,
          ));
        }
      } catch (_) {/* non-fatal */}
    }

    // 3b) Priming: a tracked area (dashboard progress) + a daily reminder so the
    // user leaves with something concrete to return to and act on.
    try {
      await repo.saveTrackedArea(TrackedArea(
        id: _uuid.v4(),
        label: value.isNotEmpty ? _short(value) : 'My goal',
        domain: 'growth',
        cadence: 'daily',
      ));
      await repo.saveReminder(ReminderPref(
        id: _uuid.v4(),
        kind: 'daily_session',
        schedule: '09:00',
        enabled: true,
      ));
    } catch (_) {/* non-fatal */}

    // 4) Record the intake itself as a session.
    final sid = _uuid.v4();
    await repo.saveSession(BloomSession(
      id: sid,
      day: today(),
      mode: 'intake',
      summary: _answers.entries.map((e) => '${e.key}: ${e.value}').join(' \n'),
      endedAt: DateTime.now().toUtc().toIso8601String(),
    ));
    var i = 0;
    for (final step in kIntakeScript) {
      await repo.saveTurn(SessionTurn(
        id: _uuid.v4(),
        sessionId: sid,
        qId: step.id,
        question: step.prompt,
        answer: _answers[step.id],
        orderIdx: i++,
      ));
    }

    await LocalDb.instance.setMeta('onboarded', '1');
    ref.invalidate(activeGoalsProvider);
    ref.invalidate(activeStepsProvider);
    ref.invalidate(memoryProvider);

    if (!mounted) return;
    setState(() => _finished = true);
    await _say(
        "Thank you, $name. I understand you a little now, and I'll remember this "
        "every time we talk. I've set up your first goal to start gently. "
        "Whenever you open Bloom, I'll be here.");
  }

  String _clean(String? s, {required String fallback}) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return fallback;
    // keep it short for a name
    return t.split(RegExp(r'[\s,.]')).first;
  }

  String _short(String s) => s.length <= 24 ? s : '${s.substring(0, 24)}…';

  Future<void> _say(String text) async {
    if (!mounted) return;
    setState(() => _caption = text);
    await _vc.speak(text, greeting: !_started);
  }

  Future<String> _getAnswer(String hint) async {
    while (mounted) {
      if (_vc.sttAvailable && !_forceText) {
        setState(() => _awaitingText = false);
        final a = await _vc.listenManual();
        if (!mounted) return a;
        if (_forceText) continue;
        if (a.isNotEmpty) return a;
        setState(() => _forceText = true);
        continue;
      } else {
        setState(() => _awaitingText = true);
        _typed = Completer<String>();
        final a = await _typed!.future;
        if (!mounted) return a;
        setState(() => _awaitingText = false);
        if (!_forceText) continue;
        return a;
      }
    }
    return '';
  }

  void _toggleMode() {
    setState(() => _forceText = !_forceText);
    if (_forceText) {
      _vc.interrupt();
    } else {
      if (_typed != null && !_typed!.isCompleted) _typed!.complete('');
    }
  }

  void _submitText() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    if (_typed != null && !_typed!.isCompleted) _typed!.complete(t);
  }

  @override
  Widget build(BuildContext context) {
    final orbSize = (MediaQuery.of(context).size.shortestSide * 0.55).clamp(160.0, 300.0);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: _forceText ? 'Use voice' : 'Type instead',
            icon: Icon(_forceText ? Icons.mic_none : Icons.keyboard),
            onPressed: _toggleMode,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              ValueListenableBuilder<VoiceState>(
                valueListenable: _vc.state,
                builder: (context, st, _) => ValueListenableBuilder<double>(
                  valueListenable: _vc.level,
                  builder: (context, lvl, __) => GestureDetector(
                    onTap: () => _vc.interrupt(),
                    child: VoiceOrb(state: st, level: lvl, size: orbSize),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_caption,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                valueListenable: _vc.partial,
                builder: (context, p, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(p,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: BloomColors.whisper, fontStyle: FontStyle.italic)),
                ),
              ),
              const Spacer(),
              if (_finished)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('BEGIN MY BLOOM'),
                  ),
                )
              else ...[
                ValueListenableBuilder<VoiceState>(
                  valueListenable: _vc.state,
                  builder: (context, st, _) {
                    if (st == VoiceState.listening && !_forceText) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: FilledButton.icon(
                          onPressed: () => _vc.finishListening(),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("I'M FINISHED"),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                if (_awaitingText || _forceText) _textInput(),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textInput() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                autofocus: _awaitingText,
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => _submitText(),
                decoration: const InputDecoration(
                  hintText: 'Type your answer…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _submitText, child: const Icon(Icons.send)),
          ],
        ),
      );
}
