import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/bloom_theme.dart';
import '../../core/voice/voice_conversation.dart';

/// An ethereal Gothic-Futurist voice orb — a luminous gold-violet being that
/// breathes when idle, ripples while speaking, pulses with the voice while
/// listening, and shimmers while thinking, wreathed in slow orbiting motes.
class VoiceOrb extends StatefulWidget {
  final VoiceState state;
  final double level; // 0..1 mic amplitude
  final double size;
  const VoiceOrb({super.key, required this.state, this.level = 0, this.size = 260});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: reduceMotion
          ? CustomPaint(painter: _OrbPainter(0, widget.state, widget.level))
          : AnimatedBuilder(
              animation: _c,
              builder: (_, __) =>
                  CustomPaint(painter: _OrbPainter(_c.value, widget.state, widget.level)),
            ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final VoiceState state;
  final double level;
  _OrbPainter(this.t, this.state, this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.width / 2;
    final breathe = 0.5 + 0.5 * math.sin(t * 2 * math.pi);

    double scale;
    bool active = false;
    switch (state) {
      case VoiceState.listening:
        scale = 0.46 + 0.30 * level + 0.04 * breathe;
        active = true;
        break;
      case VoiceState.speaking:
      case VoiceState.greeting:
        scale = 0.50 + 0.09 * math.sin(t * 7 * math.pi).abs();
        active = true;
        break;
      case VoiceState.thinking:
        scale = 0.44 + 0.05 * breathe;
        break;
      default:
        scale = 0.42 + 0.05 * breathe;
    }
    final coreR = base * scale;

    // Ambient halo
    canvas.drawCircle(
      center,
      coreR * 1.7,
      Paint()
        ..color = BloomColors.aura.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    // Expanding glow rings
    for (var i = 3; i >= 1; i--) {
      final phase = (t + i * 0.22) % 1.0;
      final r = coreR * (1 + phase * 1.1);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = (i.isEven ? BloomColors.gold : BloomColors.orchid)
              .withValues(alpha: (1 - phase) * 0.25),
      );
    }

    // Core sphere — a golden heart bleeding into deep violet (gold-dominant)
    final shader = const RadialGradient(
      colors: [
        BloomColors.goldBright, // radiant gold core
        BloomColors.gold,
        BloomColors.orchid,
        BloomColors.aura,
        Color(0xFF150E2A),
      ],
      stops: [0.0, 0.40, 0.66, 0.88, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: coreR));
    canvas.drawCircle(center, coreR, Paint()..shader = shader);

    // Inner rim light
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // Orbiting motes
    final motes = active ? 7 : 4;
    for (var i = 0; i < motes; i++) {
      final ang = t * 2 * math.pi * (i.isEven ? 1 : -1) + i * (2 * math.pi / motes);
      final orbit = coreR * (1.25 + 0.15 * math.sin(t * 2 * math.pi + i));
      final p = center + Offset(math.cos(ang), math.sin(ang)) * orbit;
      canvas.drawCircle(
        p,
        active ? 2.6 : 1.8,
        Paint()
          ..color = (i.isEven ? BloomColors.gold : BloomColors.orchid)
              .withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Thinking shimmer
    if (state == VoiceState.thinking) {
      final ang = t * 2 * math.pi;
      final hp = center + Offset(math.cos(ang), math.sin(ang)) * coreR * 0.55;
      canvas.drawCircle(hp, coreR * 0.1,
          Paint()..color = Colors.white.withValues(alpha: 0.5));
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t || old.state != state || old.level != level;
}
