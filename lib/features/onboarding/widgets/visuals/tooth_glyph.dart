import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A clean molar silhouette (buccal view) used as line art across the
/// onboarding visuals.
abstract class ToothGlyph {
  /// Width / height ratio of the silhouette.
  static const double aspectRatio = 0.80;

  /// The rect a tooth of [width] occupies, centred on [center].
  static Rect rectAt(Offset center, double width) => Rect.fromCenter(
        center: center,
        width: width,
        height: width / aspectRatio,
      );

  /// Crown, two cusps and two roots, fitted to [r].
  static Path outline(Rect r) {
    double x(double v) => r.left + v * r.width;
    double y(double v) => r.top + v * r.height;
    return Path()
      ..moveTo(x(0.10), y(0.20))
      // Mesial cusp → central fossa → distal cusp
      ..cubicTo(x(0.10), y(0.08), x(0.22), y(0.03), x(0.31), y(0.055))
      ..cubicTo(x(0.38), y(0.075), x(0.43), y(0.115), x(0.50), y(0.11))
      ..cubicTo(x(0.58), y(0.10), x(0.62), y(0.04), x(0.71), y(0.05))
      ..cubicTo(x(0.82), y(0.06), x(0.91), y(0.12), x(0.91), y(0.22))
      // Crown bulge tapering to the cervical line
      ..cubicTo(x(0.92), y(0.32), x(0.90), y(0.42), x(0.84), y(0.50))
      // Distal root
      ..cubicTo(x(0.82), y(0.62), x(0.82), y(0.78), x(0.76), y(0.92))
      ..cubicTo(x(0.74), y(0.975), x(0.68), y(0.985), x(0.66), y(0.93))
      // Furcation
      ..cubicTo(x(0.63), y(0.82), x(0.60), y(0.70), x(0.52), y(0.665))
      ..cubicTo(x(0.46), y(0.68), x(0.42), y(0.78), x(0.38), y(0.92))
      // Mesial root
      ..cubicTo(x(0.36), y(0.98), x(0.29), y(0.99), x(0.27), y(0.94))
      ..cubicTo(x(0.22), y(0.80), x(0.18), y(0.64), x(0.16), y(0.50))
      ..cubicTo(x(0.10), y(0.42), x(0.08), y(0.32), x(0.10), y(0.20))
      ..close();
  }

  /// Gentle curve where the crown meets the roots.
  static Path cervicalLine(Rect r) {
    double x(double v) => r.left + v * r.width;
    double y(double v) => r.top + v * r.height;
    return Path()
      ..moveTo(x(0.20), y(0.47))
      ..cubicTo(x(0.36), y(0.53), x(0.64), y(0.53), x(0.80), y(0.47));
  }
}

/// A check mark centred on [center], sized to sit inside a circle of
/// [radius].
void paintCheckMark(
  Canvas canvas,
  Offset center,
  double radius,
  Color color, {
  double strokeWidth = 3,
}) {
  final path = Path()
    ..moveTo(center.dx - radius * 0.40, center.dy + radius * 0.02)
    ..lineTo(center.dx - radius * 0.12, center.dy + radius * 0.30)
    ..lineTo(center.dx + radius * 0.42, center.dy - radius * 0.28);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color,
  );
}

/// A small four-point sparkle centred on [center].
void paintSparkle(Canvas canvas, Offset center, double size, Color color) {
  final path = Path();
  for (var i = 0; i < 4; i++) {
    final a = i * math.pi / 2;
    final tip = center + Offset(math.cos(a), math.sin(a)) * size;
    final side = center +
        Offset(math.cos(a + math.pi / 4), math.sin(a + math.pi / 4)) *
            (size * 0.22);
    if (i == 0) {
      path.moveTo(tip.dx, tip.dy);
    } else {
      path.lineTo(tip.dx, tip.dy);
    }
    path.lineTo(side.dx, side.dy);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}
