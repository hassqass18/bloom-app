import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/voice/mic_button.dart';
import '../../data/models/models.dart';
import '../../data/sync/sync_engine.dart';
import '../../providers.dart';
import '../session/adaptive_session_screen.dart';
import '../voice/voice_session_screen.dart';

/// The day's capture surface — mood + the six prompts + a feeling, an activity,
/// and a money entry. Offline-first: Save writes locally and triggers sync.
/// Intentionally plain — aesthetic comes later.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _uuid = const Uuid();

  int? _mood;

  // Journal prompts
  final _readSource = TextEditingController();
  final _readTakeaway = TextEditingController();
  final _watchTitle = TextEditingController();
  final _watchTakeaway = TextEditingController();
  final _word = TextEditingController();
  final _wordMeaning = TextEditingController();
  final _wordSentence = TextEditingController();
  final _proud = TextEditingController();
  final _improve = TextEditingController();
  final _thoughts = TextEditingController();

  // Feeling
  final _emotion = TextEditingController();

  // Activity
  final _activity = TextEditingController();

  // Money
  String _moneyDir = 'spent';
  final _amount = TextEditingController();
  final _category = TextEditingController();

  bool _saving = false;

  static const _moods = ['🌧 Tough', '☁️ Heavy', '🌤 Steady', '☀️ Light', '✨ Glowing'];

  int _words(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

  @override
  void dispose() {
    for (final c in [
      _readSource, _readTakeaway, _watchTitle, _watchTakeaway, _word, _wordMeaning,
      _wordSentence, _proud, _improve, _thoughts, _emotion, _activity, _amount, _category,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(entriesRepositoryProvider);
    final day = ref.read(selectedDayProvider);
    var wrote = false;

    Future<void> j(String kind, Map<String, dynamic> payload, String text) async {
      if (payload.values.every((v) => (v as String).trim().isEmpty)) return;
      await repo.addJournal(JournalEntry(
        id: _uuid.v4(), day: day, kind: kind, payload: payload, words: _words(text)));
      wrote = true;
    }

    try {
      if (_mood != null) {
        await repo.saveMood(day, _mood! + 1); // store 1..5
        wrote = true;
      }
      await j('read', {'source': _readSource.text, 'takeaway': _readTakeaway.text},
          '${_readSource.text} ${_readTakeaway.text}');
      await j('watched', {'title': _watchTitle.text, 'takeaway': _watchTakeaway.text},
          '${_watchTitle.text} ${_watchTakeaway.text}');
      await j('word', {'word': _word.text, 'meaning': _wordMeaning.text, 'sentence': _wordSentence.text},
          '${_word.text} ${_wordMeaning.text} ${_wordSentence.text}');
      await j('proud', {'body': _proud.text}, _proud.text);
      await j('improve', {'body': _improve.text}, _improve.text);
      await j('thoughts', {'body': _thoughts.text}, _thoughts.text);

      if (_emotion.text.trim().isNotEmpty) {
        await repo.addEmotion(Emotion(id: _uuid.v4(), day: day, emotion: _emotion.text.trim()));
        wrote = true;
      }
      if (_activity.text.trim().isNotEmpty) {
        await repo.addActivity(Activity(id: _uuid.v4(), day: day, title: _activity.text.trim()));
        wrote = true;
      }
      final amt = double.tryParse(_amount.text.trim());
      if (amt != null && amt > 0) {
        await repo.addMoney(MoneyEntry(
          id: _uuid.v4(), day: day, direction: _moneyDir, amount: amt,
          category: _category.text.trim().isEmpty ? null : _category.text.trim()));
        wrote = true;
      }

      unawaited(SyncEngine.instance.pushPending());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wrote ? 'Saved. Alhamdulillah. 🦋' : 'Nothing to save yet 🌸')));
        if (wrote) _clear();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clear() {
    for (final c in [
      _readSource, _readTakeaway, _watchTitle, _watchTakeaway, _word, _wordMeaning,
      _wordSentence, _proud, _improve, _thoughts, _emotion, _activity, _amount, _category,
    ]) {
      c.clear();
    }
    setState(() => _mood = null);
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(selectedDayProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Habari 🌸', style: Theme.of(context).textTheme.headlineSmall),
        Text(day, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),

        // Bloom's primary action: a Jarvis-like voice check-in that greets you,
        // asks calibrated questions out loud, and listens.
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const Text('🦋', style: TextStyle(fontSize: 26)),
            title: const Text('Talk to Bloom',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('A spoken check-in that adapts to you.'),
            trailing: const Icon(Icons.graphic_eq),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const VoiceSessionScreen())),
          ),
        ),
        // Quiet, type-only alternative.
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.keyboard, size: 18),
            label: const Text('Type instead'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AdaptiveSessionScreen())),
          ),
        ),
        const SizedBox(height: 8),

        _section('How are you today?'),
        Wrap(
          spacing: 8,
          children: List.generate(_moods.length, (i) => ChoiceChip(
            label: Text(_moods[i]),
            selected: _mood == i,
            onSelected: (_) => setState(() => _mood = _mood == i ? null : i),
          )),
        ),

        _section('Today I read'),
        _field(_readSource, 'What did you read?'),
        _field(_readTakeaway, 'What did you take from it?'),

        _section('Today I watched'),
        _field(_watchTitle, 'What did you watch?'),
        _field(_watchTakeaway, 'One thing you understood'),

        _section('New word'),
        _field(_word, 'A word you came across'),
        _field(_wordMeaning, 'What does it mean?'),
        _field(_wordSentence, 'Use it in a sentence'),

        _section("One thing I'm proud of"),
        _field(_proud, 'Big or small. Either counts.'),

        _section('One thing to improve tomorrow'),
        _field(_improve, 'Gentle with yourself.'),

        _section('On my mind'),
        _field(_thoughts, 'Whatever you want here.', lines: 4),

        _section('A feeling'),
        _field(_emotion, 'Name a feeling (e.g. serene, anxious, hopeful)'),

        _section('Something I did'),
        _field(_activity, 'An activity from today'),

        _section('Money'),
        Row(children: [
          ChoiceChip(label: const Text('Spent'), selected: _moneyDir == 'spent',
              onSelected: (_) => setState(() => _moneyDir = 'spent')),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('Earned'), selected: _moneyDir == 'earned',
              onSelected: (_) => setState(() => _moneyDir = 'earned')),
        ]),
        Row(children: [
          Expanded(child: _field(_amount, 'Amount', keyboard: TextInputType.number, voice: false)),
          const SizedBox(width: 8),
          Expanded(child: _field(_category, 'Category')),
        ]),

        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : "Save today's entry 🦋"),
        ),
        const SizedBox(height: 8),
        const Text('(skip anything that wasn\'t today)',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _field(TextEditingController c, String hint,
          {int lines = 1, TextInputType? keyboard, bool voice = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 2,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            suffixIcon: voice ? MicButton(controller: c) : null,
          ),
        ),
      );
}
