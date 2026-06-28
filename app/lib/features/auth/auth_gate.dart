import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../shell/home_shell.dart';
import 'sign_in_screen.dart';

/// Decides what to show on launch:
///  - Local-only mode (no cloud creds): straight to the app.
///  - Cloud mode: sign-in screen until there is a session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Env.hasCloud) return const HomeShell();

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        return session != null ? const HomeShell() : const SignInScreen();
      },
    );
  }
}
