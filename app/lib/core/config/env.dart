/// Compile-time configuration, supplied via --dart-define.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when cloud credentials are present. When false, Bloom runs in
  /// local-only mode (everything still works offline; no sign-in / sync).
  static bool get hasCloud =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Optional direct TTS endpoint (the secure voice proxy). When set, Bloom's
  /// branded cloud voice works without a full Supabase deploy — the API key
  /// lives in the proxy, never in this bundle.
  static const ttsUrl = String.fromEnvironment('BLOOM_TTS_URL');
  static const ttsToken = String.fromEnvironment('BLOOM_TTS_TOKEN');
  static bool get hasDirectTts => ttsUrl.isNotEmpty;

  /// Optional direct AI endpoint (the Claude brain on Vercel). When set, the app
  /// gets real adaptive questions, goal→task plans, reinforcement (no Supabase
  /// needed). Shares the BLOOM_TTS_TOKEN guard.
  static const aiUrl = String.fromEnvironment('BLOOM_AI_URL');
  static bool get hasDirectAi => aiUrl.isNotEmpty;
}
