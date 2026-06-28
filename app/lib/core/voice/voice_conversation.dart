import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'cloud_voice.dart';

/// The five canonical voice states (drives the orb + captions).
enum VoiceState { idle, greeting, listening, thinking, speaking, error }

/// A turn-based, barge-in-capable spoken conversation loop built on on-device
/// TTS (flutter_tts) + STT (speech_to_text). Works offline, no API keys.
/// A [CloudVoice] backend can later replace these for a premium realtime voice.
class VoiceConversation {
  VoiceConversation({CloudVoice cloud = const NoopCloudVoice()}) : _cloud = cloud;

  final CloudVoice _cloud;
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  final ValueNotifier<VoiceState> state = ValueNotifier(VoiceState.idle);
  final ValueNotifier<String> partial = ValueNotifier(''); // live transcript
  final ValueNotifier<double> level = ValueNotifier(0); // 0..1 mic amplitude

  bool _sttReady = false;
  bool _ttsReady = false;
  Completer<String>? _listenCompleter;

  bool get sttAvailable => _sttReady;
  bool get ttsAvailable => _ttsReady;

  Future<bool> init() async {
    try {
      _sttReady = await _stt.initialize(onError: (_) {}, onStatus: (_) {});
    } catch (_) {
      _sttReady = false;
    }
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.46); // calm, warm pace
      await _tts.setPitch(1.05);
      await _tts.setVolume(1.0);
      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
    _set(VoiceState.idle);
    debugPrint('[VC] init done sttReady=$_sttReady ttsReady=$_ttsReady cloudAvailable=${_cloud.available}');
    return _sttReady || _ttsReady;
  }

  void _set(VoiceState s) => state.value = s;

  /// Speak [text] and wait until finished. Prefers the cloud voice ("Bloom's
  /// voice" via ElevenLabs) when available; otherwise on-device TTS; otherwise a
  /// timed pause so captions stay readable.
  Future<void> speak(String text, {bool greeting = false}) async {
    if (text.trim().isEmpty) return;
    _set(greeting ? VoiceState.greeting : VoiceState.speaking);
    debugPrint('[VC] speak (cloud=${_cloud.available}, ttsReady=$_ttsReady): $text');
    try {
      if (_cloud.available) {
        // Cloud (ElevenLabs) is the ONLY voice when configured — never overlap
        // with on-device TTS. If the cloud call fails we stay silent (captions
        // remain on screen) rather than play a second, different voice.
        await _speakCloud(text);
      } else if (_ttsReady) {
        await _tts.stop();
        await _tts.speak(text);
      } else {
        // No voice engine at all: approximate reading time so captions can be read.
        await Future<void>.delayed(
            Duration(milliseconds: 350 + text.length * 28));
      }
    } catch (e) {
      debugPrint('tts error: $e');
    }
    _set(VoiceState.idle);
  }

  /// Returns true if cloud audio actually played (else caller falls back).
  /// Subscribes to completion BEFORE play (so we never miss the event), and
  /// adds a small tail pause so the end of the sentence isn't clipped.
  Future<bool> _speakCloud(String text) async {
    try {
      final bytes = <int>[];
      await for (final chunk in _cloud.synthesize(text)) {
        bytes.addAll(chunk);
      }
      if (bytes.isEmpty) return false;
      final done = Completer<void>();
      final sub = _player.onPlayerComplete.listen((_) {
        if (!done.isCompleted) done.complete();
      });
      await _player.stop();
      await _player.play(BytesSource(Uint8List.fromList(bytes)));
      await done.future.timeout(const Duration(seconds: 180), onTimeout: () {});
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      return true;
    } catch (e) {
      debugPrint('cloud voice error: $e');
      return false;
    }
  }

  /// Listen until the USER says they're done (via [finishListening]) — not on a
  /// timer. Keeps the mic open with long pause/listen windows so the person can
  /// take their time and finish a full thought. Returns the transcript.
  Future<String> listenManual() async {
    if (!_sttReady) return '';
    partial.value = '';
    _set(VoiceState.listening);
    final completer = Completer<String>();
    _listenCompleter = completer;
    try {
      await _stt.listen(
        onResult: (r) {
          partial.value = r.recognizedWords;
          // Don't auto-complete on the engine's "final" — the user controls the
          // end with the Done button. (Some engines fire final on a brief pause.)
        },
        onSoundLevelChange: (l) => level.value = ((l + 50) / 50).clamp(0.0, 1.0),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(minutes: 5),
        ),
      );
    } catch (e) {
      debugPrint('stt error: $e');
      _listenCompleter = null;
      return '';
    }
    final result = await completer.future;
    _listenCompleter = null;
    try {
      await _stt.stop();
    } catch (_) {}
    level.value = 0;
    _set(VoiceState.thinking);
    return result.trim();
  }

  /// The user tapped "Done speaking": stop the mic and finalize with whatever
  /// was captured so far (their full thought).
  Future<void> finishListening() async {
    final c = _listenCompleter;
    try {
      await _stt.stop();
    } catch (_) {}
    if (c != null && !c.isCompleted) c.complete(partial.value);
  }

  bool get isListening => _listenCompleter != null;

  /// Barge-in: stop whatever Bloom is doing (used when the user taps to talk).
  Future<void> interrupt() async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _stt.stop();
    } catch (_) {}
    final c = _listenCompleter;
    if (c != null && !c.isCompleted) c.complete(partial.value);
    _set(VoiceState.idle);
  }

  void setThinking() => _set(VoiceState.thinking);

  void dispose() {
    _tts.stop();
    _stt.cancel();
    _player.dispose();
    state.dispose();
    partial.dispose();
    level.dispose();
  }
}
