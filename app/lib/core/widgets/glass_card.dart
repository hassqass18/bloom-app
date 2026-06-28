import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/bloom_theme.dart';

/// A frosted-glass panel (dark glassmorphism): backdrop blur, violet tint + rim
/// light, soft depth. The signature surface of the Gothic-Futurist skin.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double blur;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.radius = 20,
    this.blur = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BloomColors.surface.withValues(alpha: 0.55),
                BloomColors.obsidian.withValues(alpha: 0.40),
              ],
            ),
            border: Border.all(color: BloomColors.aura.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: BloomColors.aura.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
    final wrapped = onTap == null
        ? card
        : InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: card);
    return Padding(padding: margin, child: wrapped);
  }
}
