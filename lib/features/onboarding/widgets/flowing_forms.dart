import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/onboarding_content.dart';
import 'onboarding_palette.dart';

/// White sculptural ribbons that sweep across the screen beneath each hero
/// visual: DENTRA's signature onboarding pattern.
///
/// Geometry is expressed relative to the hero square (origin at its centre,
/// one unit = its side), so the forms stay anchored under the subject at any
/// screen size. Horizontally they span the full painter width, which callers
/// extend to the screen edges.
class FlowingForms extends StatelessWidget {
  const FlowingForms({
    super.key,
    required this.visual,
    required this.heroCenter,
    required this.heroSide,
  });

  final OnboardingVisual visual;

  /// Centre and side of the hero square, in this widget's coordinates.
  final Offset heroCenter;
  final double heroSide;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _FlowingFormsPainter(
          ribbons: _ribbonsFor(visual),
          heroCenter: heroCenter,
          heroSide: heroSide,
        ),
      ),
    );
  }

  static List<_Ribbon> _ribbonsFor(OnboardingVisual visual) {
    return switch (visual) {
      // A broad swell rising from the left and settling under the tooth.
      OnboardingVisual.introduction => const [
          _Ribbon.sideForm(center: Offset(0.62, -0.18), radius: 0.42),
          _Ribbon.veil(y: [0.02, 0.42, -0.04, 0.22], t: [0.10, 0.20, 0.08]),
          _Ribbon.solid(y: [0.26, 0.50, 0.30, 0.44], t: [0.10, 0.20, 0.08]),
          _Ribbon.line(y: [0.46, 0.34, 0.60, 0.36]),
        ],
      // Rises toward the right, echoing the device's diagonal.
      OnboardingVisual.imagingDevice => const [
          _Ribbon.sideForm(center: Offset(-0.64, 0.02), radius: 0.40),
          _Ribbon.veil(y: [0.30, 0.10, 0.36, -0.12], t: [0.08, 0.16, 0.10]),
          _Ribbon.solid(y: [0.50, 0.32, 0.54, 0.24], t: [0.08, 0.17, 0.12]),
          _Ribbon.line(y: [0.60, 0.50, 0.66, 0.40]),
        ],
      // A long, continuous path under the timeline of teeth.
      OnboardingVisual.monitoring => const [
          _Ribbon.sideForm(center: Offset(-0.60, -0.22), radius: 0.38),
          _Ribbon.veil(y: [0.10, 0.36, 0.20, 0.06], t: [0.08, 0.16, 0.10]),
          _Ribbon.solid(y: [0.34, 0.44, 0.34, 0.30], t: [0.08, 0.17, 0.10]),
          _Ribbon.line(y: [0.52, 0.42, 0.56, 0.46]),
        ],
    };
  }
}

enum _RibbonStyle { veil, solid, line, sideForm }

/// One ribbon. [y] holds the top edge at the left edge, two control points
/// and the right edge; [t] holds thickness at left, middle and right. All
/// values are in hero-square units.
class _Ribbon {
  const _Ribbon.solid({required this.y, required this.t})
      : style = _RibbonStyle.solid,
        center = Offset.zero,
        radius = 0;
  const _Ribbon.veil({required this.y, required this.t})
      : style = _RibbonStyle.veil,
        center = Offset.zero,
        radius = 0;
  const _Ribbon.line({required this.y})
      : t = const [0, 0, 0],
        style = _RibbonStyle.line,
        center = Offset.zero,
        radius = 0;

  /// Large translucent disc partially entering from a screen edge.
  /// [center] and [radius] are in hero-square units.
  const _Ribbon.sideForm({required this.center, required this.radius})
      : y = const [],
        t = const [],
        style = _RibbonStyle.sideForm;

  final List<double> y;
  final List<double> t;
  final _RibbonStyle style;
  final Offset center;
  final double radius;
}

class _FlowingFormsPainter extends CustomPainter {
  const _FlowingFormsPainter({
    required this.ribbons,
    required this.heroCenter,
    required this.heroSide,
  });

  final List<_Ribbon> ribbons;
  final Offset heroCenter;
  final double heroSide;

  @override
  void paint(Canvas canvas, Size size) {
    for (final ribbon in ribbons) {
      switch (ribbon.style) {
        case _RibbonStyle.veil:
          _paintVeil(canvas, size, ribbon);
        case _RibbonStyle.solid:
          _paintSolid(canvas, size, ribbon);
        case _RibbonStyle.line:
          _paintLine(canvas, size, ribbon);
        case _RibbonStyle.sideForm:
          _paintSideForm(canvas, ribbon);
      }
    }
  }

  double _y(double unit) => heroCenter.dy + unit * heroSide;

  Path _topEdge(Size size, List<double> y) {
    final w = size.width;
    return Path()
      ..moveTo(-2, _y(y[0]))
      ..cubicTo(w * 0.34, _y(y[1]), w * 0.66, _y(y[2]), w + 2, _y(y[3]));
  }

  Path _band(Size size, _Ribbon r) {
    final w = size.width;
    final y = r.y;
    final t = r.t;
    return _topEdge(size, y)
      ..lineTo(w + 2, _y(y[3] + t[2]))
      ..cubicTo(
        w * 0.66,
        _y(y[2] + t[1]),
        w * 0.34,
        _y(y[1] + t[1]),
        -2,
        _y(y[0] + t[0]),
      )
      ..close();
  }

  /// Translucent layer that tints the teal toward white.
  void _paintVeil(Canvas canvas, Size size, _Ribbon r) {
    final band = _band(size, r);
    canvas.drawPath(
      band,
      Paint()..color = AppColors.white.withValues(alpha: 0.09),
    );
    canvas.drawPath(
      _topEdge(size, r.y),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.22),
    );
  }

  /// Opaque white form with sculpted shading and a soft cast shadow.
  void _paintSolid(Canvas canvas, Size size, _Ribbon r) {
    final band = _band(size, r);
    final bounds = band.getBounds();

    canvas.drawPath(
      band.shift(Offset(0, heroSide * 0.035)),
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, heroSide * 0.03),
    );
    canvas.drawPath(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white,
            AppColors.white,
            OnboardingPalette.mist,
            Color.lerp(OnboardingPalette.mist, OnboardingPalette.mint, 0.25)!,
          ],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ).createShader(bounds),
    );
    // Crisp highlight along the crest.
    canvas.drawPath(
      _topEdge(size, r.y),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.white,
    );
  }

  /// Soft translucent disc with a fine rim, adding depth at the edges.
  void _paintSideForm(Canvas canvas, _Ribbon r) {
    final c = heroCenter + r.center * heroSide;
    final radius = r.radius * heroSide;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            AppColors.white.withValues(alpha: 0.16),
            AppColors.white.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.18),
    );
  }

  /// Hairline contour that adds rhythm without weight.
  void _paintLine(Canvas canvas, Size size, _Ribbon r) {
    canvas.drawPath(
      _topEdge(size, r.y),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_FlowingFormsPainter old) =>
      old.ribbons != ribbons ||
      old.heroCenter != heroCenter ||
      old.heroSide != heroSide;
}
