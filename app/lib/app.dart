import 'package:flutter/material.dart';

import 'core/theme/bloom_theme.dart';
import 'features/auth/auth_gate.dart';

class BloomApp extends StatelessWidget {
  const BloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom',
      debugShowCheckedModeBanner: false,
      theme: BloomTheme.dark(),
      home: const AuthGate(),
    );
  }
}
