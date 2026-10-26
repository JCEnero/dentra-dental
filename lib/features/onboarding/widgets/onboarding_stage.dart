import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'onboarding_palette.dart';
import 'onboarding_slide_view.dart';

/// The still background behind every slide: a bright teal stage with soft
/// white light and a few faint geometric forms, and a white surface with a
/// gently curved top edge that the copy and controls sit on.
///
/// Only the light and forms respond to swiping (they drift toward each
/// slide's visual); the white surface never moves, so the copy reads as
/// sliding across one continuous sheet.
class OnboardingStage extends StatelessWidget {
  const OnboardingStage({
    super.key,
    required this.pageController,
    required this.geometry,
  });

  final PageController pageController;
  final OnboardingGeometry geometry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _StagePainter(pageController, geometry),
          ),
        ),
        // Static, so it is rasterised once and never repaints on swipes.
        RepaintBoundary(
          child: CustomPaint(painter: _SurfacePainter(geometry)),
        ),
      ],
    );
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter(this.controller, this.geometry) : super(repaint: controller);

  final PageController controller;
  final OnboardingGeometry geometry;

  /// Where the main light sits for each slide, as fractions of the stage.
  static const List<Offset> _lightCenters = [
    Offset(0.50, 0.46),
    Offset(0.66, 0.40),
    Offset(0.36, 0.44),
  ];

  double get _page {
    if (controller.hasClients && controller.position.haveDimensions) {
      return controller.page ?? 0;
    }
    return controller.initialPage.toDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stageHeight = geometry.surfaceTop + geometry.crestDepth + 2;
    final stage = Rect.fromLTWH(0, 0, w, stageHeight);
    final page = _page.clamp(0.0, _lightCenters.length - 1.0);

    // Base gradient, the Home hero card's direction and stops.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OnboardingPalette.highlight,
            OnboardingPalette.mint,
            OnboardingPalette.base,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(stage),
    );

    // Soft sheen from the top-left, like light falling across the stage.
    _glow(
      canvas,
      center: Offset(-w * 0.08, -stageHeight * 0.04),
      radius: w * 0.70,
      alpha: 0.24,
    );

    // Main light behind the visual, drifting between slides.
    final i = page.floor().clamp(0, _lightCenters.length - 2);
    final light = Offset.lerp(
      _lightCenters[i],
      _lightCenters[i + 1],
      page - i,
    )!;
    _glow(
      canvas,
      center: Offset(light.dx * w, light.dy * stageHeight),
      radius: w * 0.72,
      alpha: 0.34,
    );

    // Faint geometric forms, trailing the swipe slightly for depth.
    final drift = page * 18;
    final ringCenter = Offset(w * 1.08 - drift, -stageHeight * 0.04);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas
      ..drawCircle(
        ringCenter,
        w * 0.40,
        ring..color = AppColors.white.withValues(alpha: 0.16),
      )
      ..drawCircle(
        ringCenter,
        w * 0.58,
        ring..color = AppColors.white.withValues(alpha: 0.08),
      )
      ..drawCircle(
        Offset(-w * 0.04 - drift * 0.5, stageHeight * 0.80),
        w * 0.22,
        Paint()..color = AppColors.white.withValues(alpha: 0.07),
      );

    // White veil easing the teal into the surface.
    final veil = Rect.fromLTRB(0, stageHeight - 110, w, stageHeight);
    canvas.drawRect(
      veil,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.0),
            AppColors.white.withValues(alpha: 0.18),
          ],
        ).createShader(veil),
    );
  }

  void _glow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double alpha,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.white.withValues(alpha: alpha),
            AppColors.white.withValues(alpha: alpha * 0.35),
            AppColors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.controller != controller || old.geometry != geometry;
}

/// The white copy surface: a soft teal shadow and a hairline contour above
/// a curved edge, then white easing to a breath of mint at the bottom.
class _SurfacePainter extends CustomPainter {
  const _SurfacePainter(this.geometry);

  final OnboardingGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = geometry.surfaceTop;
    final c = geometry.crestDepth;

    // Hairline contour echoing the edge, for rhythm.
    canvas.drawPath(
      _edge(w, top - c * 0.55, top - c * 0.15, top - c * 1.05, top - c * 0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.38),
    );

    final edge = _edge(
      w,
      top + c * 0.90,
      top + c * 1.05,
      top - c * 0.10,
      top + c * 0.15,
    );
    final surface = Path.from(edge)
      ..lineTo(w + 2, h + 1)
      ..lineTo(-2, h + 1)
      ..close();

    canvas.drawPath(
      surface.shift(Offset(0, -c * 0.12)),
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, c * 0.45),
    );
    canvas.drawPath(
      surface,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.white, OnboardingPalette.surfaceTint],
        ).createShader(Rect.fromLTRB(0, top, w, h)),
    );
  }

  /// A full-width cubic edge: y at the left, y of the two control points,
  /// y at the right. Extends 2px past each side so no seam shows.
  Path _edge(double w, double y0, double y1, double y2, double y3) => Path()
    ..moveTo(-2, y0)
    ..cubicTo(w * 0.32, y1, w * 0.64, y2, w + 2, y3);

  @override
  bool shouldRepaint(_SurfacePainter old) => old.geometry != geometry;
}
