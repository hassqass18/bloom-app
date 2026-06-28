import 'dart:convert';
import 'dart:io';

import '../config/env.dart';

/// Calls the Bloom AI brain (Claude functions on Vercel) directly over HTTP.
/// Available when BLOOM_AI_URL is configured; shares the BLOOM_TTS_TOKEN guard.
/// Returns the decoded JSON map, or null on any failure (callers fall back).
class AiClient {
  static bool get available => Env.hasDirectAi;

  static Future<Map<String, dynamic>?> call(String fn, Map<String, dynamic> body) async {
    if (!available) return null;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      final req = await client.postUrl(Uri.parse('${Env.aiUrl}/$fn'));
      req.headers.set('content-type', 'application/json');
      if (Env.ttsToken.isNotEmpty) req.headers.set('x-bloom-token', Env.ttsToken);
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close().timeout(const Duration(seconds: 45));
      if (resp.statusCode != 200) return null;
      final s = await resp.transform(utf8.decoder).join();
      final d = jsonDecode(s);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
