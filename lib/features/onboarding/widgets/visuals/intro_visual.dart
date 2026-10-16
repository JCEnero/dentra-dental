import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'ambient_motion.dart';
import 'studio_stage.dart';
import 'tooth_illustration.dart';

/// Slide 1: a large molar floating above the white form, circled by a single
/// fine orbit with a slow-moving scan node.
class IntroVisual extends StatelessWidget {
  const IntroVisual({super.key, required this.animate});

  final bool animate;

  static const double _toothWidth = 182;
  static const double _toothHeight =
      _toothWidth / ToothIllustration.aspectRatio;
  static const Offset _toothCenter = Offset(160, 140);
  static const Offset _orbitCenter = Offset(160, 170);

  @override
  Widget build(BuildContext context) {
    return AmbientMotion(
      active: animate,
      period: const Duration(seconds: 9),
      restingValue: 0.30,
      child: const ToothIllustration(width: _toothWidth),
      builder: (context, t, tooth) {
        final lift = math.sin(t * 2 * math.pi * 2); // two bobs per orbit
        return Stack(
          clipBehavior: Clip.none,
          children: [
            StudioStage(
              lightCenter: const Offset(160, 140),
              floor: Rect.fromCenter(
                center: const Offset(166, 276),
                width: 132 - lift * 10,
                height: 18,
              ),
              floorOpacity: 0.8 - lift * 0.15,
            ),
            CustomPaint(
              size: const Size.square(kVisualCanvas),
              painter: _OrbitPainter(t: t, layer: _OrbitLayer.back),
            ),
            Positioned(
              left: _toothCenter.dx - _toothWidth / 2,
              top: _toothCenter.dy - _toothHeight / 2 - lift * 5,
              child: tooth!,
            ),
            CustomPaint(
              size: const Size.square(kVisualCanvas),
              painter: _OrbitPainter(t: t, layer: _OrbitLayer.front),
            ),
          ],
        );
      },
    );
  }
}

enum _OrbitLayer { back, front }

/// Draws the half of the orbit (and node) that sits behind or in front of
/// the tooth, so the ring reads as wrapping around it.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.t, required this.layer});

  final double t;
  final _OrbitLayer layer;

  static const double _rx = 146;
  static const double _ry = 34;
  static const double _tilt = -0.12;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(IntroVisual._orbitCenter.dx, IntroVisual._orbitCenter.dy);
    canvas.rotate(_tilt);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _rx * 2,
      height: _ry * 2,
    );
    final isFront = layer == _OrbitLayer.front;
    canvas.drawArc(
      rect,
      isFront ? 0 : math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: isFront ? 0.55 : 0.25),
    );

    final angle = t * 2 * math.pi;
    final nodeInFront = math.sin(angle) >= 0;
    if (nodeInFront == isFront) {
      final node = Offset(math.cos(angle) * _rx, math.sin(angle) * _ry);
      canvas.drawCircle(
        node,
        9,
        Paint()..color = AppColors.white.withValues(alpha: 0.22),
      );
      canvas.drawCircle(node, 3.5, Paint()..color = AppColors.white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t || old.layer != layer;
}
