import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/safety/crisis.dart';
import '../../core/theme/bloom_theme.dart';
import '../../core/voice/cloud_voice.dart';
import '../../core/voice/voice_conversation.dart';
import '../../core/widgets/ambient_background.dart';
import '../../data/models/models.dart' show today;
import '../../data/models/models2.dart';
import '../../providers.dart';
import '../reinforcement/reinforcement_engine.dart';
import '../session/session_engine.dart';
import 'voice_orb.dart';

/// The Jarvis-like voice-first check-in. Bloom greets you by voice the moment
/// you arrive, then asks calibrated questions out loud, listens, reflects, and
/// remembers — multimodal (captions + tap-to-type fallback), barge-in capable.
class VoiceSessionScreen extends ConsumerStatefulWidget {
  const VoiceSessionScreen({super.key});

  @override
  ConsumerState<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends ConsumerState<VoiceSessionScreen> {
  final _vc = VoiceConversation(cloud: defaultCloudVoice());
  final _engine = SessionEngine();
  final _uuid = const Uuid();
  final _text = TextEditingController();

  late final String _sessionId;
  final List<SessionTurn> _turns = [];
  List<Goal> _goals = [];
  MemoryProfile? _memory;

  String _caption = '…';
  bool _finished = false;
  bool _forceText = false;
  bool _awaitingText = false;
  Completer<String>? _typed;

  @override
  void initState() {
    super.initState();
    _sessionId = _uuid.v4();
    _boot();
  }

  @override
  void dispose() {
    _vc.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final repo = ref.read(entriesRepositoryProvider);
    await repo.saveSession(BloomSession(id: _sessionId, day: today()));
    _goals = await repo.activeGoals();
    _memory = await repo.latestMemory();
    await _vc.init();
    if (!_vc.sttAvailable) _forceText = true; // no mic recognition → typed
    await _run();
  }

  Future<void> _run() async {
    await _say(_greeting());
    while (mounted && !_finished) {
      final q = await _engine.next(goals: _goals, turns: _turns, memory: _memory);
      if (!mounted) return;
      await _say(q.question);
      final answer = await _getAnswer();
      if (!mounted) return;
      if (answer.trim().isEmpty) {
        // gentle recovery, then move on
        continue;
      }
      if (Crisis.looksLikeCrisis(answer)) {
        await Crisis.show(context);
      }
      final turn = SessionTurn(
        id: _uuid.v4(),
        sessionId: _sessionId,
        qId: q.qId,
        question: q.question,
        answer: answer,
        comBFactor: q.comBFactor,
        changeTalk: _engine.looksLikeChangeTalk(answer),
        orderIdx: _turns.length,
      );
      await ref.read(entriesRepositoryProvider).saveTurn(turn);
      setState(() => _turns.add(turn));
      if (q.isFinal) {
        await _finish();
        break;
      }
    }
  }

  String _greeting() {
    final who = _memory?.summary['who']?.toString();
    if (who != null && who.isNotEmpty) {
      return "Hey, it's me. I remember you — $who. How are you, really, today?";
    }
    return "Hi, I'm Bloom. I'm going to ask you a few gentle questions about your "
        "day — just talk to me like you would a friend. How are you, really, today?";
  }

  Future<void> _say(String text) async {
    setState(() => _caption = text);
    await _vc.speak(text);
  }

  Future<String> _getAnswer() async {
    while (mounted) {
      if (_vc.sttAvailable && !_forceText) {
        setState(() => _awaitingText = false);
        final a = await _vc.listenManual(); // returns on "I'm finished" or toggle
        if (!mounted) return a;
        if (_forceText) continue; // user toggled to keyboard mid-speech
        if (a.isNotEmpty) return a;
        setState(() => _forceText = true); // nothing heard → offer typing
        continue;
      } else {
        setState(() => _awaitingText = true);
        _typed = Completer<String>();
        final a = await _typed!.future;
        if (!mounted) return a;
        setState(() => _awaitingText = false);
        if (!_forceText) continue; // user toggled back to voice
        return a;
      }
    }
    return '';
  }

  void _toggleMode() {
    setState(() => _forceText = !_forceText);
    if (_forceText) {
      _vc.interrupt(); // stop listening → _getAnswer loops to text
    } else {
      if (_typed != null && !_typed!.isCompleted) _typed!.complete(''); // → loops to voice
    }
  }

  void _submitText() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    if (_typed != null && !_typed!.isCompleted) _typed!.complete(t);
  }

  Future<void> _finish() async {
    final repo = ref.read(entriesRepositoryProvider);
    final summary = _turns.map((t) => '${t.question} ${t.answer}').join(' \n');
    await repo.saveSession(BloomSession(
      id: _sessionId,
      day: today(),
      summary: summary,
      endedAt: DateTime.now().toUtc().toIso8601String(),
    ));
    final changeTalk = _turns.where((t) => t.changeTalk).length;
    final r = await ReinforcementEngine()
        .generate(progress: {'doneToday': 1, 'consistency': 0.5, 'changeTalk': changeTalk});
    await repo.saveReinforcement(Reinforcement(
        id: _uuid.v4(), day: today(), kind: r.kind, text: r.text, source: 'ai'));
    if (!mounted) return;
    setState(() => _finished = true);
    await _say(r.text);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orbSize = (size.shortestSide * 0.6).clamp(180.0, 320.0);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _forceText ? 'Use voice' : 'Type instead',
            icon: Icon(_forceText ? Icons.mic_none : Icons.keyboard),
            onPressed: _toggleMode,
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(true),
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
            // The orb (audio-reactive)
            ValueListenableBuilder<VoiceState>(
              valueListenable: _vc.state,
              builder: (context, st, _) => ValueListenableBuilder<double>(
                valueListenable: _vc.level,
                builder: (context, lvl, __) => GestureDetector(
                  onTap: () async {
                    // Barge-in: tap to interrupt + answer immediately.
                    await _vc.interrupt();
                  },
                  child: VoiceOrb(state: st, level: lvl, size: orbSize),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Bloom's current line (caption)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _caption,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 14),
            // Live transcript of what the user is saying
            ValueListenableBuilder<String>(
              valueListenable: _vc.partial,
              builder: (context, p, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  p,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: BloomColors.whisper, fontStyle: FontStyle.italic),
                ),
              ),
            ),
            const Spacer(),
            _statusHint(),
            if (_awaitingText || _forceText) _textInput(),
            const SizedBox(height: 12),
          ],
        ),
        ),
      ),
    );
  }

  Widget _statusHint() {
    if (_finished) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Done 🦋'),
        ),
      );
    }
    return ValueListenableBuilder<VoiceState>(
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
        final label = switch (st) {
          VoiceState.thinking => 'thinking…',
          VoiceState.speaking || VoiceState.greeting => 'Bloom is speaking…',
          _ => 'tap “use voice” to speak, or type below',
        };
        return Text(label, style: const TextStyle(color: BloomColors.whisper));
      },
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
