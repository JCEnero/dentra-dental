import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Soft, flowing page background in the spirit of the Windows 11 setup
/// screens: large blurred glows of the brand teals drifting over a pale
/// mint base.
///
/// The color sits mostly in the corners and one sweeping band, so text
/// placed directly on the page keeps a light, readable surface.
///
/// Also hosts a [BackdropGroup], letting every glass surface below share
/// a single backdrop read instead of one per card.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackdropGroup(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Static artwork: painted once, cached by the boundary.
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _AmbientPainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    // Pale mint base, slightly cooler at the top.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2F5F3), Color(0xFFF3FBFA), Color(0xFFEBF8F6)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Deep teal glow tucked into the top-right corner.
    _glow(canvas,
        center: Offset(w * 1.02, -h * 0.02),
        radius: w * 0.9,
        color: AppColors.g2,
        opacity: 0.38);

    // Cyan-mint glow on the left edge.
    _glow(canvas,
        center: Offset(-w * 0.08, h * 0.34),
        radius: w * 0.75,
        color: AppColors.g1,
        opacity: 0.30);

    // The sweeping band across the middle.
    _glow(canvas,
        center: Offset(w * 0.62, h * 0.5),
        radius: w * 0.9,
        color: AppColors.g1,
        opacity: 0.28,
        stretch: 0.36,
        angle: -0.38);

    // Deeper pool on the right, where the band settles.
    _glow(canvas,
        center: Offset(w * 1.08, h * 0.62),
        radius: w * 0.6,
        color: AppColors.g2,
        opacity: 0.24);

    // Pale highlight crest near the top, like light on a fold of fabric.
    _glow(canvas,
        center: Offset(w * 0.32, h * 0.13),
        radius: w * 0.65,
        color: AppColors.white,
        opacity: 0.75,
        stretch: 0.42,
        angle: -0.3);

    // Quiet mint pools at the bottom.
    _glow(canvas,
        center: Offset(w * 0.98, h * 0.92),
        radius: w * 0.65,
        color: AppColors.mintGreen,
        opacity: 0.40);
    _glow(canvas,
        center: Offset(-w * 0.05, h * 1.02),
        radius: w * 0.6,
        color: AppColors.lavender,
        opacity: 0.38);
  }

  /// Radial glow with a long, eased falloff so it reads as a blur rather
  /// than a shape. [stretch] squashes it into an ellipse along [angle].
  void _glow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
    double stretch = 1,
    double angle = 0,
  }) {
    final circle = Rect.fromCircle(center: Offset.zero, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * 0.55),
          color.withValues(alpha: opacity * 0.18),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.35, 0.68, 1.0],
      ).createShader(circle);

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..scale(1, stretch)
      ..drawCircle(Offset.zero, radius, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) => false;
}
