import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../onboarding_palette.dart';
import 'ambient_motion.dart';
import 'studio_stage.dart';
import 'mascot.dart';
import 'studio_props.dart';

/// Slide 2: PLACEHOLDER illustration of DENTRA's intraoral imaging device.
///
/// The real device design is not in the project, so this draws a generic
/// slim intraoral wand (handle, tapered neck, side-facing lens). The mascot
/// stands in its field of view, looking up at the lens while a scan line
/// sweeps over it. Replace it with a product render by setting `imageAsset`
/// on the second entry in `onboardingSlides`.
class DevicePlaceholderVisual extends StatelessWidget {
  const DevicePlaceholderVisual({super.key, required this.animate});

  final bool animate;

  static const Offset _floor = Offset(214, 298);
  static const double _mascotWidth = 116;
  static final Rect _mascotRect =
      Mascot.rectStandingAt(_floor, _mascotWidth);

  /// The character's visible extent (ears to feet), framed by the capture.
  static final Rect _captureTarget = Rect.fromLTRB(
    _mascotRect.left + _mascotRect.width * 0.08,
    _mascotRect.top,
    _mascotRect.right - _mascotRect.width * 0.02,
    _floor.dy,
  ).inflate(10);

  /// Centre of the mascot's face, where the lens is aimed.
  static final Offset _mascotFace = _mascotRect.topLeft +
      const Offset(105, 160) * (_mascotWidth / Mascot.designSize.width);

  @override
  Widget build(BuildContext context) {
    return AmbientMotion(
      active: animate,
      period: const Duration(milliseconds: 5200),
      restingValue: 0.2,
      builder: (context, t, _) {
        // Gentle status-light breathing, two breaths per loop.
        final pulse = 0.5 + 0.5 * math.sin(t * 4 * math.pi);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            StudioStage(
              lightCenter: const Offset(190, 160),
              floor: Rect.fromCenter(
                center: _floor.translate(0, 2),
                width: 110,
                height: 16,
              ),
            ),
            CustomPaint(
              size: const Size.square(kVisualCanvas),
              painter: _CapturePainter(
                target: _captureTarget,
                subject: _mascotFace,
              ),
            ),
            Positioned.fromRect(
              rect: _mascotRect,
              child: Mascot(width: _mascotWidth, rig: MascotRig.curious(t)),
            ),
            CustomPaint(
              size: const Size.square(kVisualCanvas),
              painter: _ScanPainter(t: t, target: _captureTarget),
            ),
            CustomPaint(
              size: const Size.square(kVisualCanvas),
              painter: _DevicePainter(pulse: pulse),
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

/// A scan line sweeping down the capture frame, twice per loop, with a soft
/// trail and a pair of sparkles riding its ends.
class _ScanPainter extends CustomPainter {
  const _ScanPainter({required this.t, required this.target});

  final double t;
  final Rect target;

  @override
  void paint(Canvas canvas, Size size) {
    final p = (t * 2) % 1.0;
    final eased = p * p * (3 - 2 * p);
    final fade = math.min(1.0, math.min(p / 0.1, (1 - p) / 0.1));
    final inner = target.deflate(6);
    final y = inner.top + inner.height * eased;

    canvas.save();
    canvas.clipRect(inner);
    final trail = Rect.fromLTRB(inner.left, y - 34, inner.right, y);
    canvas.drawRect(
      trail,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.0),
            AppColors.mintGreen.withValues(alpha: 0.28 * fade),
          ],
        ).createShader(trail),
    );
    canvas.drawLine(
      Offset(inner.left, y),
      Offset(inner.right, y),
      Paint()
        ..strokeWidth = 4
        ..color = AppColors.g1.withValues(alpha: 0.5 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      Offset(inner.left, y),
      Offset(inner.right, y),
      Paint()
        ..strokeWidth = 1.4
        ..color = AppColors.white.withValues(alpha: 0.95 * fade),
    );
    canvas.restore();

    StudioProps.sparkle(canvas, Offset(inner.left, y), 5, opacity: fade);
    StudioProps.sparkle(canvas, Offset(inner.right, y), 5, opacity: fade);
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t || old.target != target;
}

/// Field of view and viewfinder, drawn behind the mascot.
class _CapturePainter extends CustomPainter {
  const _CapturePainter({required this.target, required this.subject});

  final Rect target;
  final Offset subject;

  @override
  void paint(Canvas canvas, Size size) {
    final lens = _DevicePainter.lensPosition();
    _paintBeam(canvas, lens);
    _paintViewfinder(canvas);
  }

  /// A soft beam of light from the lens, widening toward the subject.
  void _paintBeam(Canvas canvas, Offset lens) {
    final axis = subject - lens;
    final normal = Offset(-axis.dy, axis.dx) / axis.distance;
    const spread = 46.0;
    final beam = Path()
      ..moveTo(lens.dx, lens.dy)
      ..lineTo(subject.dx + normal.dx * spread, subject.dy + normal.dy * spread)
      ..lineTo(subject.dx - normal.dx * spread, subject.dy - normal.dy * spread)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = ui.Gradient.linear(lens, subject, [
          AppColors.white.withValues(alpha: 0.45),
          AppColors.white.withValues(alpha: 0.0),
        ])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  /// Corner brackets marking the captured frame.
  void _paintViewfinder(Canvas canvas) {
    final r = target;
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
  bool shouldRepaint(_CapturePainter old) => old.target != target;
}

class _DevicePainter extends CustomPainter {
  const _DevicePainter({required this.pulse});

  final double pulse;

  // Device axis: from the handle end to the head tip, in design space.
  static const Offset _start = Offset(304, 10);
  static const Offset _tip = Offset(118, 140);

  // Proportions of a slim intraoral wand.
  static const double _halfHandle = 15;
  static const double _halfNeck = 7.5;
  static const double _halfHead = 10;

  static Matrix4 _transform() {
    final axis = _tip - _start;
    return Matrix4.identity()
      ..translateByDouble(_start.dx, _start.dy, 0, 1)
      ..rotateZ(axis.direction);
  }

  static Offset _lensLocal() =>
      Offset((_tip - _start).distance * 0.915, -_halfHead * 0.35);

  /// Lens centre in design space, where the field of view starts.
  static Offset lensPosition() =>
      MatrixUtils.transformPoint(_transform(), _lensLocal());

  @override
  void paint(Canvas canvas, Size size) {
    final length = (_tip - _start).distance;
    final transform = _transform();
    final body = _silhouette(length);
    final lensLocal = _lensLocal();

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

  @override
  bool shouldRepaint(_DevicePainter old) => old.pulse != pulse;
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
