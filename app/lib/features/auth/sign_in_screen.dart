import 'package:flutter/material.dart';

import '../../core/supabase/supabase_service.dart';

/// Minimal email one-time-passcode sign-in. (Google/Apple added later.)
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  Future<void> _send() async {
    setState(() { _busy = true; _error = null; });
    try {
      await SupabaseService.signInWithEmailOtp(_email.text.trim());
      setState(() => _codeSent = true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _error = null; });
    try {
      await SupabaseService.verifyEmailOtp(_email.text.trim(), _code.text.trim());
      // AuthGate will rebuild on the auth state change.
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bloom', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text('Your days, growing into something you can see.'),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Code from your email'),
                  ),
                ],
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                FilledButton(
                  onPressed: _busy ? null : (_codeSent ? _verify : _send),
                  child: Text(_busy ? '…' : (_codeSent ? 'Verify & enter' : 'Send me a code')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
