import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../onboarding_palette.dart';

/// Small set pieces that dress the mascot's onboarding scenes. Each draws in
/// design-space coordinates with the same studio lighting as the mascot.
abstract class StudioProps {
  /// Lavender accent borrowed from the mascot's inner ears.
  static const Color periwinkle = Color(0xFFC6C9F1);

  /// A four-point twinkle with a soft glow.
  static void sparkle(Canvas canvas, Offset c, double r,
      {double opacity = 1, double rotation = 0}) {
    if (opacity <= 0 || r <= 0) return;
    canvas.drawCircle(
      c,
      r * 1.1,
      Paint()
        ..color = AppColors.white.withValues(alpha: 0.35 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    const k = 0.14;
    canvas.drawPath(
      Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(r * k, -r * k, r, 0)
        ..quadraticBezierTo(r * k, r * k, 0, r)
        ..quadraticBezierTo(-r * k, r * k, -r, 0)
        ..quadraticBezierTo(-r * k, -r * k, 0, -r)
        ..close(),
      Paint()..color = AppColors.white.withValues(alpha: opacity),
    );
    canvas.restore();
  }

  /// A glossy soap bubble with an iridescent edge.
  static void bubble(Canvas canvas, Offset c, double r, {double opacity = 1}) {
    if (opacity <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            AppColors.white.withValues(alpha: 0.05 * opacity),
            AppColors.white.withValues(alpha: 0.12 * opacity),
            AppColors.mintGreen.withValues(alpha: 0.35 * opacity),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, r * 0.07)
        ..color = AppColors.white.withValues(alpha: 0.7 * opacity),
    );
    canvas.drawArc(
      rect.deflate(r * 0.14),
      0.1 * math.pi,
      0.55 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round
        ..color = periwinkle.withValues(alpha: 0.8 * opacity),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-r * 0.38, -r * 0.42),
        width: r * 0.5,
        height: r * 0.32,
      ),
      Paint()..color = AppColors.white.withValues(alpha: 0.9 * opacity),
    );
  }

  /// A white and teal toothbrush with a swirl of toothpaste, centred on [c]
  /// and pointing its head along [angle].
  static void toothbrush(Canvas canvas, Offset c,
      {required double length, double angle = 0}) {
    final s = length / 122;
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(angle)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-61, 10, 0, 1);

    final body = Path.combine(
      PathOperation.union,
      Path()
        ..addRRect(RRect.fromLTRBR(0, -6, 82, 6, const Radius.circular(6))),
      Path.combine(
        PathOperation.union,
        Path()
          ..moveTo(76, -5)
          ..cubicTo(84, -3.6, 88, -3.4, 96, -3.4)
          ..lineTo(96, 3.4)
          ..cubicTo(88, 3.4, 84, 3.6, 76, 5)
          ..close(),
        Path()
          ..addRRect(
              RRect.fromLTRBR(92, -6.5, 122, 4.5, const Radius.circular(5))),
      ),
    );

    // Floating drop shadow cast straight down onto the backdrop.
    canvas.drawPath(
      body.transform(m.storage).shift(const Offset(6, 16)),
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.save();
    canvas.transform(m.storage);

    // Bristle tufts, alternating white and mint.
    for (var i = 0; i < 6; i++) {
      final tuft = RRect.fromLTRBR(
        95.0 + i * 4.3,
        -17,
        98.4 + i * 4.3,
        -5,
        const Radius.circular(1.6),
      );
      canvas.drawRRect(
        tuft,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: i.isEven
                ? const [AppColors.white, Color(0xFFDDE4EA)]
                : const [AppColors.mintGreen, AppColors.g1],
          ).createShader(tuft.outerRect),
      );
    }

    // Handle: cylinder shading lit from the top.
    final bounds = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.white, AppColors.offWhite, Color(0xFFD3D8E2)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(bounds),
    );
    // Teal grip inlay.
    final grip = RRect.fromLTRBR(14, -3.4, 58, 3.4, const Radius.circular(3.4));
    canvas.drawRRect(
      grip,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.g1, AppColors.g2],
        ).createShader(grip.outerRect),
    );
    final shine = Paint()
      ..color = AppColors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(18, -1.8), const Offset(54, -1.8), shine);
    canvas.drawLine(const Offset(6, -3.8), const Offset(12, -3.8), shine);
    canvas.drawLine(const Offset(64, -3.6), const Offset(80, -3.6), shine);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = AppColors.navy.withValues(alpha: 0.12),
    );

    // Toothpaste swirl: three scoops with a mint stripe.
    for (final (x, y, r) in const [
      (99.0, -19.5, 4.6),
      (113.5, -19.5, 4.6),
      (106.0, -22.5, 5.2),
    ]) {
      final rect = Rect.fromCircle(center: Offset(x, y), radius: r);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            colors: [AppColors.white, Color(0xFFE3E8EE)],
          ).createShader(rect),
      );
      canvas.drawArc(
        rect.deflate(r * 0.35),
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.42
          ..strokeCap = StrokeCap.round
          ..color = AppColors.g1.withValues(alpha: 0.85),
      );
    }
    canvas.drawCircle(
      const Offset(104, -25.5),
      1.4,
      Paint()..color = AppColors.white,
    );
    canvas.restore();
  }

  /// A round white badge with a teal check mark.
  static void checkBadge(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c.translate(0, r * 0.3),
      r,
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
    );
    final outer = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [AppColors.white, AppColors.offWhite, Color(0xFFD9E2E6)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(outer),
    );
    final inner = Rect.fromCircle(center: c, radius: r * 0.72);
    canvas.drawCircle(
      c,
      r * 0.72,
      Paint()..shader = AppColors.cardGradient.createShader(inner),
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.32, c.dy + r * 0.02)
        ..lineTo(c.dx - r * 0.08, c.dy + r * 0.26)
        ..lineTo(c.dx + r * 0.34, c.dy - r * 0.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.17
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.white,
    );
    canvas.drawArc(
      outer.deflate(r * 0.08),
      math.pi * 1.1,
      math.pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round
        ..color = AppColors.white,
    );
  }

  /// Tumbling confetti falling through [area]. Loops seamlessly in [t].
  static void confetti(Canvas canvas, Rect area, double t, {int count = 18}) {
    const colors = [
      AppColors.white,
      AppColors.mintGreen,
      AppColors.coral,
      periwinkle,
      AppColors.warmOrange,
      AppColors.white,
    ];
    for (var i = 0; i < count; i++) {
      final seedA = (i * 0.618034) % 1.0;
      final seedB = (i * 0.754878 + 0.31) % 1.0;
      final p = (t * (1 + i % 2) + seedA) % 1.0;
      final fade =
          math.min(1.0, math.min(p / 0.12, (1 - p) / 0.25)).clamp(0.0, 1.0);
      final pos = Offset(
        area.left +
            area.width * seedB +
            math.sin((p * 2 + seedA) * 2 * math.pi) * 7,
        area.top + area.height * p,
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate((p * (i.isEven ? 2 : -2) + seedA * 3) * 2 * math.pi);
      // Flip on one axis so pieces appear to tumble in 3D.
      canvas.scale(0.25 + 0.75 * math.cos((p * 3 + seedB) * 2 * math.pi).abs(), 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 4.4, height: 7.6),
          const Radius.circular(1.4),
        ),
        Paint()..color = colors[i % colors.length].withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  /// A glossy round display pedestal whose top face is centred on [top].
  static void pedestal(Canvas canvas, Offset top,
      {required double radius, double depth = 12, double glow = 0.5}) {
    final ry = radius * 0.2;
    final topRect = Rect.fromCenter(center: top, width: radius * 2, height: ry * 2);
    final bottomRect = topRect.shift(Offset(0, depth));

    canvas.drawOval(
      bottomRect.inflate(6).shift(const Offset(5, 7)),
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final side = Path()
      ..moveTo(topRect.left, top.dy)
      ..lineTo(bottomRect.left, bottomRect.center.dy)
      ..arcTo(bottomRect, math.pi, -math.pi, false)
      ..lineTo(topRect.right, top.dy)
      ..arcTo(topRect, 0, math.pi, false)
      ..close();
    canvas.drawPath(
      side,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFE6F7F5),
            AppColors.white,
            Color(0xFFD4EFEC),
            AppColors.mintGreen,
          ],
          stops: [0.0, 0.3, 0.75, 1.0],
        ).createShader(side.getBounds()),
    );

    canvas.drawOval(
      topRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.4),
          radius: 0.9,
          colors: [AppColors.white, AppColors.offWhite, Color(0xFFE2F2F0)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(topRect),
    );

    // Inset light ring, pulsing with [glow].
    final ring = topRect.deflate(radius * 0.1);
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.g1.withValues(alpha: 0.18 + glow * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.g1.withValues(alpha: 0.45 + glow * 0.35),
    );

    // Specular rim along the front edge.
    canvas.drawArc(
      topRect.deflate(0.8),
      math.pi * 0.15,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.white,
    );
  }
}
