import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../onboarding_palette.dart';

/// A studio-lit molar drawn with layered vector shading.
///
/// This is a 2D illustration with 3D-style lighting, not a 3D model. It is
/// the shared hero element across the onboarding visuals until real renders
/// are supplied via `OnboardingSlideContent.imageAsset`.
class ToothIllustration extends StatelessWidget {
  const ToothIllustration({super.key, required this.width});

  final double width;

  /// Width / height ratio of the drawing.
  static const double aspectRatio = 0.80;

  @override
  Widget build(BuildContext context) {
    // The tooth never changes, so cache its raster separately from any
    // motion applied by parents.
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, width / aspectRatio),
        painter: const _ToothPainter(),
      ),
    );
  }
}

class _ToothPainter extends CustomPainter {
  const _ToothPainter();

  /// Molar silhouette (buccal view, slight top-down tilt) in unit space.
  static Path _outline(Size s) {
    double x(double v) => v * s.width;
    double y(double v) => v * s.height;
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

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bounds = Offset.zero & size;
    final body = _outline(size);

    // Contact shadow cast onto the backdrop.
    canvas.drawPath(
      body.shift(Offset(w * 0.025, h * 0.035)),
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );

    canvas.save();
    canvas.clipPath(body);

    // 1. Enamel base: key light from the upper left.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-0.8, -1),
          end: Alignment(0.7, 1),
          colors: [AppColors.white, AppColors.offWhite, AppColors.border],
          stops: [0.0, 0.42, 1.0],
        ).createShader(bounds),
    );

    // 2. Warmer, matte root surface below the cervical line.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.peachBg.withValues(alpha: 0.0),
            AppColors.peachBg.withValues(alpha: 0.30),
            AppColors.peachBg.withValues(alpha: 0.55),
          ],
          stops: const [0.46, 0.62, 1.0],
        ).createShader(bounds),
    );

    // 3. Cylindrical falloff toward both silhouette edges.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.navy.withValues(alpha: 0.10),
            AppColors.navy.withValues(alpha: 0.0),
            AppColors.navy.withValues(alpha: 0.0),
            AppColors.navy.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.26, 0.60, 1.0],
        ).createShader(bounds),
    );

    // 4. Ambient occlusion where crown meets root.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.navy.withValues(alpha: 0.0),
            AppColors.navy.withValues(alpha: 0.09),
            AppColors.navy.withValues(alpha: 0.0),
          ],
          stops: const [0.40, 0.51, 0.62],
        ).createShader(bounds),
    );

    // 5. Cusp lobes catching the light.
    for (final lobe in const [Offset(0.31, 0.19), Offset(0.70, 0.18)]) {
      final c = Offset(lobe.dx * w, lobe.dy * h);
      final r = w * 0.24;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.white.withValues(alpha: 0.95),
              AppColors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // 6. Buccal developmental groove between the cusps.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.50, h * 0.11)
        ..quadraticBezierTo(w * 0.515, h * 0.22, w * 0.49, h * 0.33),
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.018),
    );

    // 7. Faint enamel growth lines for surface texture.
    final texture = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final row in const [0.30, 0.35, 0.40]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.14, h * row)
          ..quadraticBezierTo(w * 0.50, h * (row + 0.025), w * 0.87, h * row),
        texture,
      );
    }

    // 8. Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.25, h * 0.25),
        width: w * 0.07,
        height: h * 0.15,
      ),
      Paint()
        ..color = AppColors.white.withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.015),
    );

    canvas.restore();

    // Cool mint rim light on the shadow side, separating the tooth from the
    // turquoise background.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..shader = LinearGradient(
          colors: [
            AppColors.mintGreen.withValues(alpha: 0.0),
            AppColors.mintGreen.withValues(alpha: 0.0),
            AppColors.mintGreen.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(bounds),
    );

    // Hairline edge definition.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.navy.withValues(alpha: 0.07),
    );
  }

  @override
  bool shouldRepaint(_ToothPainter oldDelegate) => false;
}
