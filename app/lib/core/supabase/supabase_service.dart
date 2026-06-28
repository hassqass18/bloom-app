import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Thin wrapper around Supabase init + auth. Safe no-ops in local-only mode.
class SupabaseService {
  static Future<void> init() async {
    if (!Env.hasCloud) return; // local-only mode
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient? get clientOrNull =>
      Env.hasCloud ? Supabase.instance.client : null;

  static SupabaseClient get client => Supabase.instance.client;

  static bool get isSignedIn =>
      Env.hasCloud && Supabase.instance.client.auth.currentSession != null;

  static String? get userId =>
      Env.hasCloud ? Supabase.instance.client.auth.currentUser?.id : null;

  /// Email one-time-passcode sign-in (no password). Sends a code/link.
  static Future<void> signInWithEmailOtp(String email) async {
    await client.auth.signInWithOtp(email: email);
  }

  static Future<void> verifyEmailOtp(String email, String token) async {
    await client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  static Future<void> signOut() async {
    if (Env.hasCloud) await client.auth.signOut();
  }
}
