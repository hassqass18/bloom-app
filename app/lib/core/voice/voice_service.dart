import 'package:flutter/widgets.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// On-device speech-to-text. One active capture at a time; writes recognized
/// words straight into the bound text controller. Falls back to typing if the
/// platform doesn't support speech or permission is denied.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;

  Future<bool> _ensure() async {
    _ready = _ready || await _stt.initialize();
    return _ready;
  }

  bool get isListening => _stt.isListening;

  /// Begin listening, appending to [c]. Returns false if speech is unavailable.
  Future<bool> start(TextEditingController c, {VoidCallback? onChange}) async {
    if (!await _ensure()) return false;
    final base = c.text.isEmpty ? '' : '${c.text} ';
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        c.text = base + r.recognizedWords;
        c.selection = TextSelection.collapsed(offset: c.text.length);
        onChange?.call();
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
    return true;
  }

  Future<void> stop() => _stt.stop();
}
