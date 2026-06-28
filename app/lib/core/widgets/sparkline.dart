import 'package:flutter/material.dart';

/// A tiny dependency-free line chart for trends ("see it, not feel it").
class Sparkline extends StatelessWidget {
  final List<double> values;
  final double height;
  final Color? color;
  const Sparkline(this.values, {super.key, this.height = 56, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: values.length < 2
          ? Center(
              child: Text('Not enough data yet 🌱',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)))
          : CustomPaint(painter: _SparkPainter(values, c)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  _SparkPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = v.reduce((a, b) => a > b ? a : b);
    final minV = v.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (v.length - 1);
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = dx * i;
      final y = size.height - ((v[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // soft fill under the line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fillPath, Paint()..color = color.withValues(alpha: 0.10));
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.v != v || old.color != color;
}
