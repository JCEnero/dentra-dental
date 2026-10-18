import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../onboarding_palette.dart';

/// Design-space edge length every onboarding illustration is composed in.
/// `OnboardingHeroVisual` scales this square to the space available.
const double kVisualCanvas = 320;

/// Shared staging for the onboarding illustrations: a soft white
/// key-light pool and an optional floor shadow, so all three slides read as
/// one studio set against the turquoise backdrop.
class StudioStage extends StatelessWidget {
  const StudioStage({
    super.key,
    this.lightCenter = const Offset(160, 160),
    this.floor,
    this.floorOpacity = 1.0,
  });

  final Offset lightCenter;

  /// Floor shadow ellipse in design-space coordinates.
  final Rect? floor;

  /// Lets floating subjects soften their shadow as they rise.
  final double floorOpacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(kVisualCanvas),
      painter: _StudioStagePainter(
        lightCenter: lightCenter,
        floor: floor,
        floorOpacity: floorOpacity,
      ),
    );
  }
}

class _StudioStagePainter extends CustomPainter {
  const _StudioStagePainter({
    required this.lightCenter,
    required this.floor,
    required this.floorOpacity,
  });

  final Offset lightCenter;
  final Rect? floor;
  final double floorOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 158.0;
    canvas.drawCircle(
      lightCenter,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.white.withValues(alpha: 0.30),
            AppColors.white.withValues(alpha: 0.10),
            AppColors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: lightCenter, radius: radius)),
    );

    final floorRect = floor;
    if (floorRect != null) {
      // A blurred oval keeps its elliptical footprint (a radial gradient
      // would collapse to a circle on a wide rect).
      canvas.drawOval(
        floorRect.deflate(floorRect.shortestSide * 0.25),
        Paint()
          ..color =
              OnboardingPalette.shadow.withValues(alpha: 0.45 * floorOpacity)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            floorRect.shortestSide * 0.35,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_StudioStagePainter old) =>
      old.lightCenter != lightCenter ||
      old.floor != floor ||
      old.floorOpacity != floorOpacity;
}
