import 'package:flutter/material.dart';

import 'voice_service.dart';

/// Tap to dictate into [controller]. Tap again to stop. Degrades gracefully.
class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.controller});
  final TextEditingController controller;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  bool _listening = false;

  Future<void> _toggle() async {
    final v = VoiceService.instance;
    if (_listening) {
      await v.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await v.start(widget.controller, onChange: () {
      if (mounted) setState(() {});
    });
    if (!mounted) return;
    if (ok) {
      setState(() => _listening = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice not available here — typing works fine 💕')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_listening ? Icons.mic : Icons.mic_none),
      color: _listening ? Theme.of(context).colorScheme.primary : null,
      tooltip: 'Dictate',
      onPressed: _toggle,
    );
  }
}
