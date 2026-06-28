import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/bloom_theme.dart';

/// The shared atmosphere: a near-black void with slow-drifting violet aura orbs
/// behind everything. Honors reduced-motion. Wrap any screen body in this.
class AmbientBackground extends StatefulWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 32))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      color: BloomColors.bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: reduceMotion
                ? CustomPaint(painter: _AuraPainter(0))
                : AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => CustomPaint(painter: _AuraPainter(_c.value)),
                  ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  final double t;
  _AuraPainter(this.t);

  void _orb(Canvas canvas, Size s, double cx, double cy, double r, Color color) {
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final a = t * 2 * math.pi;
    _orb(canvas, size, w * (0.25 + 0.10 * math.sin(a)), h * (0.22 + 0.06 * math.cos(a)),
        w * 0.55, BloomColors.halo.withValues(alpha: 0.55));
    _orb(canvas, size, w * (0.82 + 0.08 * math.cos(a * 0.8)),
        h * (0.35 + 0.07 * math.sin(a * 0.8)), w * 0.5, BloomColors.aura.withValues(alpha: 0.18));
    _orb(canvas, size, w * (0.6 + 0.10 * math.sin(a * 0.6 + 1)),
        h * (0.85 + 0.05 * math.cos(a * 0.6)), w * 0.6, BloomColors.orchid.withValues(alpha: 0.12));
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.t != t;
}
