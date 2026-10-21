import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../onboarding_palette.dart';
import 'ambient_motion.dart';
import 'onboarding_hero_visual.dart';
import 'tooth_glyph.dart';

/// Slide 3: a screening history as a gently rising timeline. Three past
/// check-ins (small glass nodes with a tooth) lead to a larger node with a
/// check mark; a soft light travels the path. No numbers or data.
class MonitoringVisual extends StatelessWidget {
  const MonitoringVisual({super.key, required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AmbientMotion(
      active: animate,
      period: const Duration(milliseconds: 5200),
      restingValue: 0.0,
      builder: (context, t, _) => CustomPaint(
        size: const Size.square(kVisualCanvas),
        painter: _MonitoringPainter(t),
      ),
    );
  }
}

class _MonitoringPainter extends CustomPainter {
  _MonitoringPainter(this.t);

  final double t;

  static const double _baseline = 262;
  static const List<double> _checkIns = [0.0, 0.32, 0.62];

  static final Path _path = Path()
    ..moveTo(46, 232)
    ..cubicTo(102, 236, 128, 190, 168, 166)
    ..cubicTo(204, 144, 230, 112, 262, 98);
  static final PathMetric _metric = _path.computeMetrics().first;

  Offset _at(double fraction) =>
      _metric.getTangentForOffset(_metric.length * fraction)!.position;

  @override
  void paint(Canvas canvas, Size size) {
    final end = _at(1);

    // Baseline and drop lines, like a quiet timeline axis.
    final guide = Paint()
      ..strokeWidth = 1
      ..color = AppColors.white.withValues(alpha: 0.24);
    canvas.drawLine(
      const Offset(30, _baseline),
      const Offset(290, _baseline),
      guide,
    );
    for (final f in [..._checkIns, 1.0]) {
      _dashedDrop(canvas, _at(f), guide);
    }

    // Track, then the path itself.
    canvas
      ..drawPath(
        _path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = AppColors.white.withValues(alpha: 0.14),
      )
      ..drawPath(
        _path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = AppColors.white.withValues(alpha: 0.92),
      );

    // Light travelling the path, easing in and out.
    final travel = Curves.easeInOutCubic.transform(t);
    final light = _at(travel);
    final fade = math.sin(t * math.pi);
    canvas
      ..drawCircle(
        light,
        11,
        Paint()
          ..color = AppColors.white.withValues(alpha: 0.45 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..drawCircle(
        light,
        3.2,
        Paint()..color = AppColors.white.withValues(alpha: fade),
      );

    // Past check-ins.
    for (final f in _checkIns) {
      final at = _at(f);
      _glassNode(canvas, at, 16);
      final tooth = ToothGlyph.rectAt(at, 12.5);
      canvas.drawPath(
        ToothGlyph.outline(tooth),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round
          ..color = OnboardingPalette.ink,
      );
    }

    // Latest check-in: a pulse ring, then the check mark.
    final pulse = Curves.easeOut.transform(t);
    canvas.drawCircle(
      end,
      30 + pulse * 16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.white.withValues(alpha: 0.55 * (1 - pulse)),
    );
    _glassNode(canvas, end, 30);
    paintCheckMark(canvas, end, 30, OnboardingPalette.ink, strokeWidth: 3.6);
  }

  void _glassNode(Canvas canvas, Offset at, double radius) {
    final rect = Rect.fromCircle(center: at, radius: radius);
    canvas
      ..drawCircle(
        at.translate(0, radius * 0.25),
        radius,
        Paint()
          ..color = OnboardingPalette.shadow.withValues(alpha: 0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45),
      )
      ..drawCircle(
        at,
        radius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.45),
            radius: 1.1,
            colors: [AppColors.white, OnboardingPalette.mist],
          ).createShader(rect),
      )
      ..drawCircle(
        at,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.white,
      );
  }

  void _dashedDrop(Canvas canvas, Offset from, Paint paint) {
    const dash = 4.0;
    const gap = 5.0;
    for (var y = from.dy + 12; y < _baseline - 2; y += dash + gap) {
      canvas.drawLine(
        Offset(from.dx, y),
        Offset(from.dx, math.min(y + dash, _baseline - 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MonitoringPainter old) => old.t != t;
}
