import 'package:flutter/material.dart';

import '../../core/theme/bloom_theme.dart';
import '../../core/voice/cloud_voice.dart';
import '../../core/voice/voice_conversation.dart';
import '../voice/voice_orb.dart';
import 'page_guides.dart';

/// Wraps any page and pins a small luminous orb in the corner. Tap it and Bloom
/// voice-guides the user through the current page (ElevenLabs). Tap again to stop.
/// This is the always-available, toggleable in-context guide.
class BloomGuideOverlay extends StatefulWidget {
  final String pageId;
  final Widget child;
  const BloomGuideOverlay({super.key, required this.pageId, required this.child});

  @override
  State<BloomGuideOverlay> createState() => _BloomGuideOverlayState();
}

class _BloomGuideOverlayState extends State<BloomGuideOverlay> {
  final VoiceConversation _vc = VoiceConversation(cloud: defaultCloudVoice());
  bool _guiding = false;

  @override
  void initState() {
    super.initState();
    _vc.init();
  }

  @override
  void dispose() {
    _vc.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_guiding) {
      await _vc.interrupt();
      if (mounted) setState(() => _guiding = false);
      return;
    }
    final lines = kPageGuides[widget.pageId] ?? const [];
    if (lines.isEmpty) return;
    setState(() => _guiding = true);
    // Speak the whole guide as ONE utterance so it flows naturally (no
    // topic-to-topic cutoffs between separate audio clips).
    await _vc.speak(lines.join('  '));
    if (mounted) setState(() => _guiding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 14,
          bottom: 90,
          child: GestureDetector(
            onTap: _toggle,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: BloomColors.aura.withValues(alpha: 0.4),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ValueListenableBuilder<VoiceState>(
                valueListenable: _vc.state,
                builder: (context, st, _) => ValueListenableBuilder<double>(
                  valueListenable: _vc.level,
                  builder: (context, lvl, __) => VoiceOrb(state: st, level: lvl, size: 62),
                ),
              ),
            ),
          ),
        ),
        // tiny "tap me to guide you" hint dot when idle (first impression)
        if (!_guiding)
          const Positioned(
            right: 14,
            bottom: 156,
            child: IgnorePointer(
              child: Text('tap me',
                  style: TextStyle(color: BloomColors.whisper, fontSize: 10)),
            ),
          ),
      ],
    );
  }
}
