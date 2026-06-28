import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/safety/crisis.dart';
import '../../data/models/models.dart' show today;
import '../../data/models/models2.dart';
import '../../providers.dart';
import '../reinforcement/reinforcement_engine.dart';
import 'session_engine.dart';

/// The adaptive daily check-in: calibrated, therapist-style questions that adapt
/// to the previous answer (MI/OARS + Socratic + CAT) — never a static form.
class AdaptiveSessionScreen extends ConsumerStatefulWidget {
  const AdaptiveSessionScreen({super.key});

  @override
  ConsumerState<AdaptiveSessionScreen> createState() => _AdaptiveSessionScreenState();
}

class _AdaptiveSessionScreenState extends ConsumerState<AdaptiveSessionScreen> {
  final _engine = SessionEngine();
  final _uuid = const Uuid();
  final _answer = TextEditingController();
  final _scroll = ScrollController();

  late final String _sessionId;
  final List<SessionTurn> _turns = [];
  List<Goal> _goals = [];
  MemoryProfile? _memory;
  NextQuestion? _current;
  bool _thinking = true;
  bool _finished = false;
  String? _closingMessage;

  @override
  void initState() {
    super.initState();
    _sessionId = _uuid.v4();
    _begin();
  }

  @override
  void dispose() {
    _answer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    final repo = ref.read(entriesRepositoryProvider);
    await repo.saveSession(BloomSession(id: _sessionId, day: today()));
    _goals = await repo.activeGoals();
    _memory = await repo.latestMemory();
    await _next();
  }

  Future<void> _next() async {
    setState(() => _thinking = true);
    final q = await _engine.next(goals: _goals, turns: _turns, memory: _memory);
    if (mounted) {
      setState(() {
        _current = q;
        _thinking = false;
      });
      _scrollDown();
    }
  }

  Future<void> _submit() async {
    final text = _answer.text.trim();
    final q = _current;
    if (text.isEmpty || q == null) return;
    _answer.clear();

    // Safety first: if the answer signals crisis, stop and surface help.
    if (Crisis.looksLikeCrisis(text)) {
      await Crisis.show(context);
    }

    final repo = ref.read(entriesRepositoryProvider);
    final turn = SessionTurn(
      id: _uuid.v4(),
      sessionId: _sessionId,
      qId: q.qId,
      question: q.question,
      answer: text,
      comBFactor: q.comBFactor,
      changeTalk: _engine.looksLikeChangeTalk(text),
      orderIdx: _turns.length,
    );
    await repo.saveTurn(turn);
    setState(() => _turns.add(turn));
    _scrollDown();

    if (q.isFinal) {
      await _finish();
    } else {
      await _next();
    }
  }

  Future<void> _finish() async {
    setState(() => _thinking = true);
    final repo = ref.read(entriesRepositoryProvider);
    final summary = _turns.map((t) => '${t.question} ${t.answer}').join(' \n');
    await repo.saveSession(BloomSession(
      id: _sessionId,
      day: today(),
      summary: summary,
      endedAt: DateTime.now().toUtc().toIso8601String(),
    ));
    final changeTalk = _turns.where((t) => t.changeTalk).length;
    final r = await ReinforcementEngine().generate(progress: {
      'doneToday': 1,
      'consistency': 0.5,
      'changeTalk': changeTalk,
    });
    await repo.saveReinforcement(Reinforcement(
        id: _uuid.v4(), day: today(), kind: r.kind, text: r.text, source: 'ai'));
    if (mounted) {
      setState(() {
        _finished = true;
        _thinking = false;
        _closingMessage = r.text;
      });
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's check-in")),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                for (final t in _turns) ...[
                  _bubble(t.question, bloom: true),
                  _bubble(t.answer ?? '', bloom: false),
                ],
                if (!_finished && _current != null && !_thinking)
                  _bubble(_current!.question, bloom: true),
                if (_thinking)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('…', style: TextStyle(fontSize: 22, color: Colors.grey)),
                  ),
                if (_finished) _closing(),
              ],
            ),
          ),
          if (!_finished) _inputBar(),
        ],
      ),
    );
  }

  Widget _closing() => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('🦋', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(_closingMessage ?? 'Thank you for showing up today.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );

  Widget _bubble(String text, {required bool bloom}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: bloom ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bloom
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _inputBar() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answer,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Type your answer… (you can always skip)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.skip_next),
                      tooltip: 'Skip',
                      onPressed: _thinking
                          ? null
                          : () {
                              if (_current?.isFinal == true) {
                                _finish();
                              } else {
                                _next();
                              }
                            },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _thinking ? null : _submit,
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      );
}
