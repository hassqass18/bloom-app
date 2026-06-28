import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../config/env.dart';
import '../supabase/supabase_service.dart';

/// Picks the best available cloud voice: the direct proxy (if a BLOOM_TTS_URL is
/// configured), else the Supabase `tts` Edge Function, else none (on-device).
CloudVoice defaultCloudVoice() {
  if (Env.hasDirectTts) return const DirectCloudVoice();
  return const ElevenLabsVoice();
}

/// "My Voice in the cloud" — abstraction for a premium, low-latency realtime
/// voice backend. The on-device path ([VoiceConversation]) works today with no
/// keys; this interface lets a cloud voice drop in unchanged.
///
/// Chosen stack: **ElevenLabs (TTS) + Claude (brain)** — a warm, branded "Bloom"
/// voice. The API key stays server-side in the `tts` Edge Function.
abstract class CloudVoice {
  /// True when the cloud path is reachable (cloud configured + signed in).
  /// If the server has no ElevenLabs key it returns no audio and the caller
  /// falls back to the on-device voice — so this can be true yet still degrade
  /// gracefully.
  bool get available;

  /// Synthesize [text] to audio bytes (mp3). Empty stream → use on-device voice.
  Stream<List<int>> synthesize(String text);
}

/// Default no-op backend: signals "use the on-device path."
class NoopCloudVoice implements CloudVoice {
  const NoopCloudVoice();
  @override
  bool get available => false;
  @override
  Stream<List<int>> synthesize(String text) => const Stream.empty();
}

/// Direct cloud voice via a standalone TTS proxy (the local/edge `tts` server
/// that holds the ElevenLabs key). Works without a full Supabase deploy.
class DirectCloudVoice implements CloudVoice {
  const DirectCloudVoice();

  @override
  bool get available => Env.hasDirectTts;

  @override
  Stream<List<int>> synthesize(String text) async* {
    if (!available || text.trim().isEmpty) return;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      final req = await client.postUrl(Uri.parse(Env.ttsUrl));
      req.headers.set('content-type', 'application/json');
      if (Env.ttsToken.isNotEmpty) req.headers.set('x-bloom-token', Env.ttsToken);
      req.add(utf8.encode(jsonEncode({'text': text})));
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final bytes = <int>[];
        await for (final chunk in resp) {
          bytes.addAll(chunk);
        }
        if (bytes.isNotEmpty) yield bytes;
      }
    } catch (_) {
      // network/timeout → empty → on-device fallback
    } finally {
      client?.close(force: true);
    }
  }
}

/// ElevenLabs-backed cloud voice via the server-side `tts` Edge Function.
/// Switch-on: set ELEVENLABS_API_KEY in the function env + deploy. No app
/// changes needed; the key never touches the device.
class ElevenLabsVoice implements CloudVoice {
  const ElevenLabsVoice();

  @override
  bool get available => Env.hasCloud && SupabaseService.isSignedIn;

  @override
  Stream<List<int>> synthesize(String text) async* {
    if (!available || text.trim().isEmpty) return;
    try {
      final res = await SupabaseService.client.functions.invoke(
        'tts',
        body: {'text': text},
      );
      final data = res.data;
      if (data is Uint8List && data.isNotEmpty) {
        yield data;
      } else if (data is List<int> && data.isNotEmpty) {
        yield data;
      }
      // Anything else (204 / JSON / null) → empty → on-device fallback.
    } catch (_) {
      // Network/parse error → silent fallback to on-device voice.
    }
  }
}
