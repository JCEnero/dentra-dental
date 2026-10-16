import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../onboarding_palette.dart';
import 'ambient_motion.dart';
import 'studio_stage.dart';
import 'tooth_illustration.dart';

/// Slide 2: PLACEHOLDER illustration of DENTRA's intraoral imaging device.
///
/// The real device design is not in the project, so this draws a generic
/// slim intraoral wand (handle, tapered neck, side-facing lens) capturing a
/// tooth. It shows no capabilities beyond "a handheld device captures an
/// image". Replace it with a product render by setting `imageAsset` on the
/// second entry in `onboardingSlides`.
class DevicePlaceholderVisual extends StatelessWidget {
  const DevicePlaceholderVisual({super.key, required this.animate});

  final bool animate;

  static const double _toothWidth = 72;
  static const Rect _toothRect = Rect.fromLTWH(
    200 - _toothWidth / 2,
    240 - _toothWidth / ToothIllustration.aspectRatio / 2,
    _toothWidth,
    _toothWidth / ToothIllustration.aspectRatio,
  );

  @override
  Widget build(BuildContext context) {
    return AmbientMotion(
      active: animate,
      period: const Duration(milliseconds: 2600),
      restingValue: 0.5,
      child: const ToothIllustration(width: _toothWidth),
      builder: (context, t, tooth) {
        // Gentle status-light breathing.
        final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            StudioStage(
              lightCenter: const Offset(176, 150),
              floor: Rect.fromCenter(
                center: Offset(_toothRect.center.dx, _toothRect.bottom + 14),
                width: 96,
                height: 14,
              ),
            ),
            Positioned.fromRect(rect: _toothRect, child: tooth!),
            CustomPaint(
              size: const Size.square(kVisualCanvas),
              painter: _DevicePainter(
                pulse: pulse,
                captureTarget: _toothRect.inflate(12),
              ),
            ),
            if (kDebugMode)
              const Positioned(
                left: 0,
                top: 0,
                child: _PlaceholderTag(),
              ),
          ],
        );
      },
    );
  }
}

class _DevicePainter extends CustomPainter {
  const _DevicePainter({required this.pulse, required this.captureTarget});

  final double pulse;
  final Rect captureTarget;

  // Device axis: from the handle end to the head tip, in design space.
  static const Offset _start = Offset(300, 34);
  static const Offset _tip = Offset(124, 179);

  // Proportions of a slim intraoral wand.
  static const double _halfHandle = 15;
  static const double _halfNeck = 7.5;
  static const double _halfHead = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = _tip - _start;
    final length = axis.distance;
    final angle = axis.direction;
    final transform = Matrix4.identity()
      ..translateByDouble(_start.dx, _start.dy, 0, 1)
      ..rotateZ(angle);

    final body = _silhouette(length);
    final lensLocal = Offset(length * 0.915, -_halfHead * 0.35);
    final lens = MatrixUtils.transformPoint(transform, lensLocal);

    _paintCaptureCone(canvas, lens);
    _paintViewfinder(canvas);

    // Soft shadow cast down and away from the key light.
    canvas.drawPath(
      body.transform(transform.storage).shift(const Offset(6, 14)),
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.save();
    canvas.transform(transform.storage);
    _paintBody(canvas, body, length);
    _paintLens(canvas, lensLocal);
    _paintStatusLight(canvas, Offset(length * 0.46, _halfHandle * 0.15));
    canvas.restore();
  }

  Path _silhouette(double l) {
    const t = _halfHandle;
    const n = _halfNeck;
    const hd = _halfHead;
    return Path()
      ..moveTo(t, -t)
      ..lineTo(l * 0.58, -t)
      ..cubicTo(l * 0.66, -t, l * 0.68, -n, l * 0.76, -n)
      ..lineTo(l * 0.84, -n)
      ..cubicTo(l * 0.86, -n, l * 0.86, -hd, l * 0.88, -hd)
      ..lineTo(l - hd, -hd)
      ..arcToPoint(Offset(l - hd, hd), radius: const Radius.circular(hd))
      ..lineTo(l * 0.88, hd)
      ..cubicTo(l * 0.86, hd, l * 0.86, n, l * 0.84, n)
      ..lineTo(l * 0.76, n)
      ..cubicTo(l * 0.68, n, l * 0.66, t, l * 0.58, t)
      ..lineTo(t, t)
      ..arcToPoint(const Offset(t, -t), radius: const Radius.circular(t))
      ..close();
  }

  void _paintBody(Canvas canvas, Path body, double l) {
    const t = _halfHandle;
    final shadeRect = Rect.fromLTRB(0, -t, l, t);

    canvas.save();
    canvas.clipPath(body);

    // Cylinder shading across the device's thickness. In this orientation
    // local +y faces the key light.
    canvas.drawRect(
      shadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.white,
            AppColors.white,
            AppColors.offWhite,
            AppColors.border,
            Color.lerp(AppColors.border, AppColors.navy, 0.30)!,
          ],
          stops: const [0.0, 0.18, 0.42, 0.80, 1.0],
        ).createShader(shadeRect),
    );

    // Matte grip section.
    canvas.drawRect(
      Rect.fromLTRB(l * 0.06, -t, l * 0.30, t),
      Paint()..color = AppColors.navy.withValues(alpha: 0.045),
    );

    // Panel seams.
    final seam = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.12)
      ..strokeWidth = 0.9;
    canvas.drawLine(Offset(l * 0.30, -t), Offset(l * 0.30, t), seam);
    canvas.drawLine(Offset(l * 0.06, -t), Offset(l * 0.06, t), seam);

    // Long specular streak along the lit side.
    canvas.drawLine(
      Offset(l * 0.08, t * 0.55),
      Offset(l * 0.56, t * 0.55),
      Paint()
        ..color = AppColors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.navy.withValues(alpha: 0.10),
    );
  }

  void _paintLens(Canvas canvas, Offset c) {
    final rect = Rect.fromCenter(center: c, width: 13, height: 8);
    canvas.drawOval(
      rect,
      Paint()..color = AppColors.navy.withValues(alpha: 0.92),
    );
    canvas.drawOval(
      rect.deflate(1.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.g1.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      c.translate(-2.2, 1.2),
      1.1,
      Paint()..color = AppColors.white.withValues(alpha: 0.85),
    );
  }

  void _paintStatusLight(Canvas canvas, Offset c) {
    canvas.drawCircle(
      c,
      6 + pulse * 1.5,
      Paint()..color = AppColors.g1.withValues(alpha: 0.10 + pulse * 0.12),
    );
    canvas.drawCircle(c, 2.4, Paint()..color = AppColors.g1);
  }

  /// A faint field of view from the lens toward the tooth.
  void _paintCaptureCone(Canvas canvas, Offset lens) {
    final cone = Path()
      ..moveTo(lens.dx, lens.dy)
      ..lineTo(captureTarget.right, captureTarget.top)
      ..lineTo(captureTarget.left, captureTarget.bottom)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.28),
            AppColors.white.withValues(alpha: 0.02),
          ],
        ).createShader(cone.getBounds()),
    );
    final edge = Paint()
      ..color = AppColors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    canvas.drawLine(lens, captureTarget.topRight, edge);
    canvas.drawLine(lens, captureTarget.bottomLeft, edge);
  }

  /// Corner brackets marking the captured frame.
  void _paintViewfinder(Canvas canvas) {
    final r = captureTarget;
    const arm = 12.0;
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final (corner, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
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

  @override
  bool shouldRepaint(_DevicePainter old) =>
      old.pulse != pulse || old.captureTarget != captureTarget;
}

/// Debug-only marker so nobody ships the placeholder by mistake.
class _PlaceholderTag extends StatelessWidget {
  const _PlaceholderTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        'DEVICE RENDER PLACEHOLDER',
        style: GoogleFonts.outfit(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppColors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
