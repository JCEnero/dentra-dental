import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../onboarding_palette.dart';
import 'ambient_motion.dart';
import 'onboarding_hero_visual.dart';
import 'tooth_glyph.dart';

/// Slide 2: digital dental screening. A white molar inside a glass
/// viewfinder with corner brackets and a faint sampling grid; a line of
/// light sweeps up and down, and two areas of interest brighten as it
/// passes. Purely illustrative, with no scores or findings.
class ScreeningVisual extends StatelessWidget {
  const ScreeningVisual({super.key, required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AmbientMotion(
      active: animate,
      period: const Duration(milliseconds: 4200),
      // Resting frame: the line just past the upper marker.
      restingValue: 0.30,
      builder: (context, t, _) => CustomPaint(
        size: const Size.square(kVisualCanvas),
        painter: _ScreeningPainter(t),
      ),
    );
  }
}

class _ScreeningPainter extends CustomPainter {
  const _ScreeningPainter(this.t);

  final double t;

  static const Offset _center = Offset(kVisualCanvas / 2, kVisualCanvas / 2);
  static final RRect _frame = RRect.fromRectAndRadius(
    Rect.fromCenter(center: _center, width: 232, height: 232),
    const Radius.circular(40),
  );
  static final Rect _tooth = ToothGlyph.rectAt(_center.translate(0, 4), 116);

  /// Areas of interest on the crown.
  static const List<Offset> _markers = [Offset(134, 122), Offset(186, 152)];

  @override
  void paint(Canvas canvas, Size size) {
    // Glass viewfinder.
    canvas
      ..drawRRect(
        _frame,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.white.withValues(alpha: 0.22),
              AppColors.white.withValues(alpha: 0.08),
            ],
          ).createShader(_frame.outerRect),
      )
      ..drawRRect(
        _frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.white.withValues(alpha: 0.45),
      );

    // Sampling grid.
    final grid = _frame.outerRect.deflate(30);
    final dot = Paint()..color = AppColors.white.withValues(alpha: 0.22);
    const steps = 6;
    for (var i = 0; i <= steps; i++) {
      for (var j = 0; j <= steps; j++) {
        canvas.drawCircle(
          Offset(
            grid.left + grid.width * i / steps,
            grid.top + grid.height * j / steps,
          ),
          1.3,
          dot,
        );
      }
    }

    _paintBrackets(canvas, _frame.outerRect.deflate(14));

    // The tooth, lifted off the glass by a soft teal shadow.
    final outline = ToothGlyph.outline(_tooth);
    canvas
      ..drawPath(
        outline.shift(const Offset(0, 10)),
        Paint()
          ..color = OnboardingPalette.shadow.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      )
      ..drawPath(
        outline,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.white, OnboardingPalette.mist],
          ).createShader(_tooth),
      )
      ..drawPath(
        ToothGlyph.cervicalLine(_tooth),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = OnboardingPalette.ink.withValues(alpha: 0.22),
      );

    // Sweep: eased up and down the frame.
    final inner = _frame.outerRect.deflate(18);
    final s = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
    final lineY = inner.top + s * inner.height;
    final goingDown = math.sin(t * 2 * math.pi) >= 0;

    for (final marker in _markers) {
      final near = (1 - (lineY - marker.dy).abs() / 70).clamp(0.0, 1.0);
      _paintMarker(canvas, marker, near);
    }

    canvas
      ..save()
      ..clipRRect(_frame);
    // Trail of light behind the line.
    const trail = 54.0;
    final trailRect = goingDown
        ? Rect.fromLTRB(inner.left, lineY - trail, inner.right, lineY)
        : Rect.fromLTRB(inner.left, lineY, inner.right, lineY + trail);
    canvas.drawRect(
      trailRect,
      Paint()
        ..shader = LinearGradient(
          begin: goingDown ? Alignment.topCenter : Alignment.bottomCenter,
          end: goingDown ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.0),
            AppColors.white.withValues(alpha: 0.26),
          ],
        ).createShader(trailRect),
    );
    final line = Rect.fromLTRB(inner.left, lineY - 1, inner.right, lineY + 1);
    final lineShader = LinearGradient(
      colors: [
        AppColors.white.withValues(alpha: 0.0),
        AppColors.white,
        AppColors.white.withValues(alpha: 0.0),
      ],
    ).createShader(line);
    canvas
      ..drawRect(
        line.inflate(3),
        Paint()
          ..shader = lineShader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawRect(line, Paint()..shader = lineShader)
      ..restore();
  }

  void _paintBrackets(Canvas canvas, Rect r) {
    const arm = 24.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.white.withValues(alpha: 0.95);
    for (final (corner, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy + dy * arm)
          ..lineTo(corner.dx, corner.dy + dy * 8)
          ..quadraticBezierTo(
            corner.dx,
            corner.dy,
            corner.dx + dx * 8,
            corner.dy,
          )
          ..lineTo(corner.dx + dx * arm, corner.dy),
        paint,
      );
    }
  }

  /// A rounded focus box with a centre dot. Always visible (so the resting
  /// frame reads), brighter and slightly larger while the line is near.
  void _paintMarker(Canvas canvas, Offset at, double near) {
    final side = 22 + near * 3;
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: side, height: side),
      const Radius.circular(7),
    );
    final color = OnboardingPalette.ink.withValues(alpha: 0.45 + near * 0.55);
    canvas
      ..drawRRect(
        box,
        Paint()..color = OnboardingPalette.mint.withValues(alpha: near * 0.18),
      )
      ..drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color,
      )
      ..drawCircle(at, 2.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScreeningPainter old) => old.t != t;
}
