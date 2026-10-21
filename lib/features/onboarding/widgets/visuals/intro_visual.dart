import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../onboarding_palette.dart';
import 'ambient_motion.dart';
import 'onboarding_hero_visual.dart';
import 'tooth_glyph.dart';

/// Slide 1: a line-art molar on a frosted glass disc, centred in three fine
/// concentric orbits with two slow-moving nodes. Calm and symmetrical, as
/// a first impression of the brand.
class IntroVisual extends StatelessWidget {
  const IntroVisual({super.key, required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AmbientMotion(
      active: animate,
      period: const Duration(seconds: 16),
      restingValue: 0.12,
      builder: (context, t, _) => CustomPaint(
        size: const Size.square(kVisualCanvas),
        painter: _IntroPainter(t),
      ),
    );
  }
}

class _IntroPainter extends CustomPainter {
  const _IntroPainter(this.t);

  /// Loop progress, 0 → 1.
  final double t;

  static const Offset _center = Offset(kVisualCanvas / 2, kVisualCanvas / 2);
  static const double _discRadius = 70;

  @override
  void paint(Canvas canvas, Size size) {
    final turn = t * 2 * math.pi;
    // Four slow breaths per loop.
    final breathe = math.sin(turn * 4);

    // Orbits, fading outward.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (radius, alpha) in const [
      (150.0, 0.16),
      (122.0, 0.26),
      (96.0, 0.40),
    ]) {
      canvas.drawCircle(
        _center,
        radius,
        ring..color = AppColors.white.withValues(alpha: alpha),
      );
    }

    // A bright arc travelling the middle orbit, led by a node.
    const arcRadius = 122.0;
    final arcStart = turn - math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: _center, radius: arcRadius),
      arcStart,
      0.85,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        // Fades in along the arc; rotated (not offset) so it stays valid
        // as the arc crosses angle zero.
        ..shader = SweepGradient(
          endAngle: 0.85,
          colors: [
            AppColors.white.withValues(alpha: 0.0),
            AppColors.white.withValues(alpha: 0.9),
          ],
          transform: GradientRotation(arcStart),
        ).createShader(Rect.fromCircle(center: _center, radius: arcRadius)),
    );
    _node(canvas, _polar(arcRadius, arcStart + 0.85), 4.5, 1.0);
    // A fainter node on the outer orbit, turning the other way.
    _node(canvas, _polar(150, -turn + math.pi * 0.8), 3, 0.75);

    // Glass disc with a soft teal shadow.
    final r = _discRadius + breathe * 1.2;
    canvas.drawCircle(
      _center.translate(0, 14),
      r - 4,
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    final disc = Rect.fromCircle(center: _center, radius: r);
    canvas
      ..drawCircle(
        _center,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.45),
            radius: 1.1,
            colors: [
              AppColors.white.withValues(alpha: 0.97),
              OnboardingPalette.mist.withValues(alpha: 0.90),
            ],
          ).createShader(disc),
      )
      ..drawCircle(
        _center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.white.withValues(alpha: 0.95),
      );

    // Line-art tooth, floating very slightly.
    final tooth =
        ToothGlyph.rectAt(_center.translate(0, -1 + breathe * 1.6), 74);
    final outline = ToothGlyph.outline(tooth);
    canvas
      ..drawPath(
        outline,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.white, OnboardingPalette.mist],
          ).createShader(tooth),
      )
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..color = OnboardingPalette.ink,
      )
      ..drawPath(
        ToothGlyph.cervicalLine(tooth),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = OnboardingPalette.ink.withValues(alpha: 0.35),
      );

    // One small sparkle, gently pulsing.
    paintSparkle(
      canvas,
      _center.translate(36, -44),
      6.5 + breathe * 1.2,
      OnboardingPalette.turquoise,
    );
  }

  Offset _polar(double radius, double angle) =>
      _center + Offset(math.cos(angle), math.sin(angle)) * radius;

  void _node(Canvas canvas, Offset at, double radius, double alpha) {
    canvas
      ..drawCircle(
        at,
        radius * 2.4,
        Paint()
          ..color = AppColors.white.withValues(alpha: 0.22 * alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius),
      )
      ..drawCircle(
        at,
        radius,
        Paint()..color = AppColors.white.withValues(alpha: alpha),
      );
  }

  @override
  bool shouldRepaint(_IntroPainter old) => old.t != t;
}
