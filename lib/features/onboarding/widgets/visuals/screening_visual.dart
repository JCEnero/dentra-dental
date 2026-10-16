import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'ambient_motion.dart';
import 'studio_stage.dart';
import 'tooth_illustration.dart';

/// Slide 3: a tooth inside a fine capture frame, swept by a scanning plane
/// and circled by slow scanning arcs. Detection outlines appear as the plane
/// passes them. No scores or results are shown: the visual says "analysed",
/// never "diagnosed".
class ScreeningVisual extends StatelessWidget {
  const ScreeningVisual({super.key, required this.animate});

  final bool animate;

  static const Rect _frame = Rect.fromLTRB(70, 34, 250, 270);
  static const double _toothWidth = 140;
  static final Rect _toothRect = Rect.fromCenter(
    center: const Offset(160, 150),
    width: _toothWidth,
    height: _toothWidth / ToothIllustration.aspectRatio,
  );

  /// Detection outlines in tooth-relative coordinates.
  static const List<Offset> _markers = [Offset(0.34, 0.20), Offset(0.70, 0.38)];

  // Timeline within one loop: sweep, hold the result, fade out.
  static const double _sweepEnd = 0.68;
  static const double _fadeStart = 0.92;

  @override
  Widget build(BuildContext context) {
    return AmbientMotion(
      active: animate,
      period: const Duration(milliseconds: 4800),
      // At rest: the sweep has finished and both outlines are shown.
      restingValue: 0.80,
      child: const ToothIllustration(width: _toothWidth),
      builder: (context, t, tooth) {
        final sweep = (t / _sweepEnd).clamp(0.0, 1.0);
        final scanY = _frame.top + 8 + (_frame.height - 16) * sweep;
        final lineOpacity =
            t < _sweepEnd ? 1.0 : (1 - (t - _sweepEnd) / 0.08).clamp(0.0, 1.0);
        final fadeOut = t < _fadeStart
            ? 1.0
            : (1 - (t - _fadeStart) / 0.08).clamp(0.0, 1.0);

        final markers = [
          for (final m in _markers)
            _marker(
              Offset(
                _toothRect.left + m.dx * _toothRect.width,
                _toothRect.top + m.dy * _toothRect.height,
              ),
              scanY,
              fadeOut,
            ),
        ];

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const StudioStage(lightCenter: Offset(160, 150)),
            Positioned.fromRect(rect: _toothRect, child: tooth!),
            CustomPaint(
              size: const Size.square(kVisualCanvas),
              painter: _AnalysisPainter(
                frame: _frame,
                center: _toothRect.center,
                arcTurn: t,
                scanY: scanY,
                lineOpacity: lineOpacity,
                markers: markers,
              ),
            ),
          ],
        );
      },
    );
  }

  static ({Offset position, double opacity}) _marker(
    Offset position,
    double scanY,
    double fadeOut,
  ) {
    final revealed = ((scanY - position.dy) / 18).clamp(0.0, 1.0);
    return (position: position, opacity: revealed * fadeOut);
  }
}

class _AnalysisPainter extends CustomPainter {
  const _AnalysisPainter({
    required this.frame,
    required this.center,
    required this.arcTurn,
    required this.scanY,
    required this.lineOpacity,
    required this.markers,
  });

  final Rect frame;
  final Offset center;
  final double arcTurn;
  final double scanY;
  final double lineOpacity;
  final List<({Offset position, double opacity})> markers;

  @override
  void paint(Canvas canvas, Size size) {
    _paintArcs(canvas);
    _paintFrame(canvas);
    if (lineOpacity > 0) _paintScanPlane(canvas);
    for (final m in markers) {
      if (m.opacity > 0) _paintOutline(canvas, m.position, m.opacity);
    }
  }

  /// Two fine partial rings turning slowly in opposite directions.
  void _paintArcs(Canvas canvas) {
    final turn = arcTurn * 2 * math.pi;
    for (final (radius, start, sweep, alpha) in [
      (128.0, -0.9 + turn * 0.25, 1.1, 0.45),
      (140.0, 2.2 - turn * 0.15, 0.7, 0.25),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = AppColors.white.withValues(alpha: alpha),
      );
    }
  }

  void _paintFrame(Canvas canvas) {
    const arm = 16.0;
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final (corner, dx, dy) in [
      (frame.topLeft, 1.0, 1.0),
      (frame.topRight, -1.0, 1.0),
      (frame.bottomLeft, 1.0, -1.0),
      (frame.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx * arm, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy * arm),
        paint,
      );
    }
  }

  void _paintScanPlane(Canvas canvas) {
    final inner = frame.deflate(8);
    canvas.save();
    canvas.clipRect(inner);

    // Trail of already-analysed area above the line.
    final trail = Rect.fromLTRB(inner.left, scanY - 48, inner.right, scanY);
    canvas.drawRect(
      trail,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.0),
            AppColors.white.withValues(alpha: 0.18 * lineOpacity),
          ],
        ).createShader(trail),
    );

    final line =
        Rect.fromLTRB(inner.left, scanY - 0.7, inner.right, scanY + 0.7);
    canvas.drawRect(
      line,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.white.withValues(alpha: 0.0),
            AppColors.white.withValues(alpha: 0.95 * lineOpacity),
            AppColors.white.withValues(alpha: 0.95 * lineOpacity),
            AppColors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ).createShader(line),
    );
    canvas.restore();
  }

  /// Fine detection outline: a thin rounded box with a centre point, drawn
  /// in brand teal so it reads against the white enamel.
  void _paintOutline(Canvas canvas, Offset c, double opacity) {
    final box = Rect.fromCenter(center: c, width: 26, height: 26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(7)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.g2.withValues(alpha: 0.9 * opacity),
    );
    canvas.drawCircle(
      c,
      2.2,
      Paint()..color = AppColors.g2.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_AnalysisPainter old) =>
      old.arcTurn != arcTurn ||
      old.scanY != scanY ||
      old.lineOpacity != lineOpacity ||
      old.markers != markers;
}
