import 'dart:math';

import 'package:flutter/material.dart';

class DonutSlice {
  const DonutSlice(this.value, this.color);

  final int value;
  final Color color;
}

/// A ring chart with small gaps between slices and text in the middle.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, required this.center, this.size = 180});

  final List<DonutSlice> slices;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DonutPainter(slices, Theme.of(context).colorScheme.surfaceContainerHighest),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.track);

  final List<DonutSlice> slices;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.14;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, 2 * pi, false, paint..color = track);
    final total = slices.fold<int>(0, (a, s) => a + s.value);
    if (total == 0) return;
    final gap = slices.length > 1 ? 0.03 : 0.0;
    var angle = -pi / 2;
    for (final s in slices) {
      final sweep = 2 * pi * s.value / total;
      if (sweep > gap) {
        canvas.drawArc(rect, angle + gap / 2, sweep - gap, false, paint..color = s.color);
      }
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices || old.track != track;
}
