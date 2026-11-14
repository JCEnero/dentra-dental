import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/constants/app_colors.dart';

/// An abstract composition for behind the sign-in form: soft organic blobs
/// in the brand's teals and mints, a flowing ribbon, glass spheres, a thin
/// ring and a frosted tile, scattered toward the edges so the glass card
/// frosts whatever runs under it.
///
/// The blobs slowly change shape, the ribbon ripples and the spheres float.
/// Everything fades in as the screen opens. Holds still under reduced
/// motion.
class AuthAbstractBackdrop extends StatefulWidget {
  const AuthAbstractBackdrop({super.key});

  @override
  State<AuthAbstractBackdrop> createState() => _AuthAbstractBackdropState();
}

class _AuthAbstractBackdropState extends State<AuthAbstractBackdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) {
    _seconds.value = elapsed.inMicroseconds / 1e6;
  });
  final _seconds = ValueNotifier<double>(0);
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _AbstractPainter(
            _seconds,
            _still,
            MediaQuery.paddingOf(context).top,
          ),
        ),
      ),
    );
  }
}

/// One organic blob: its centre and size as fractions of the screen's
/// width, its two colours, and its own beat so no two move together.
class _Blob {
  const _Blob(
      this.x, this.y, this.r, this.from, this.to, this.alpha, this.seed);

  final double x, y, r;
  final Color from, to;
  final double alpha;
  final double seed;
}

class _AbstractPainter extends CustomPainter {
  _AbstractPainter(this.seconds, this.still, this.topInset)
      : super(repaint: seconds);

  final ValueNotifier<double> seconds;
  final bool still;

  /// The status bar's height: the logo sits just under it.
  final double topInset;

  static const _blobs = [
    // Top right, the largest, behind the logo's far side.
    _Blob(0.98, 0.12, 0.56, AppColors.g1, AppColors.g2, 0.5, 0.0),
    // Left, about where the card's upper half sits.
    _Blob(
        -0.04, 0.42, 0.4, AppColors.mintGreen, AppColors.cardSolid, 0.48, 1.7),
    // Right, under the card's lower corner, clear of the footer.
    _Blob(1.04, 0.64, 0.3, AppColors.lavender, AppColors.g1, 0.55, 3.1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = still ? 0.0 : seconds.value;
    final w = size.width, h = size.height;
    // Everything fades in as the screen opens.
    final enter =
        still ? 1.0 : Curves.easeOutCubic.transform((t / 0.9).clamp(0.0, 1.0));
    if (enter <= 0) return;

    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, enter),
    );

    for (final b in _blobs) {
      _paintBlob(canvas, Offset(b.x * w, b.y * h), b.r * w, b, t);
    }

    _paintRibbon(canvas, size, t);

    // A frosted tile, turned, peeking out at the left.
    _paintTile(
      canvas,
      Offset(0.08 * w, 0.3 * h + 4 * math.sin(t * 0.6)),
      0.2 * w,
      -0.42 + 0.04 * math.sin(t * 0.3),
    );

    // A thin ring on the right.
    final ring = Offset(0.86 * w, 0.5 * h + 5 * math.sin(t * 0.5 + 1));
    canvas
      ..drawCircle(
        ring,
        0.15 * w,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.white.withValues(alpha: 0.8),
      )
      ..drawCircle(
        ring,
        0.15 * w - 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.g2.withValues(alpha: 0.14),
      );

    // Glass spheres, floating.
    _paintSphere(
        canvas, Offset(0.1 * w, 0.76 * h + 6 * math.sin(t * 0.7)), 0.09 * w);
    _paintSphere(canvas, Offset(0.16 * w, 0.14 * h + 4 * math.sin(t * 0.8 + 2)),
        0.045 * w);
    _paintSphere(canvas, Offset(0.9 * w, 0.86 * h + 4 * math.sin(t * 0.6 + 4)),
        0.05 * w);

    // A clear patch of light where the logo sits, so it reads cleanly.
    final logo = Rect.fromCenter(
      center: Offset(w / 2, topInset + 32),
      width: w * 0.9,
      height: 120,
    );
    canvas.drawOval(
      logo,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.white.withValues(alpha: 0.92),
          AppColors.white.withValues(alpha: 0.6),
          AppColors.white.withValues(alpha: 0),
        ], stops: const [
          0,
          0.5,
          1
        ]).createShader(logo),
    );

    canvas.restore();
  }

  /// A soft, slowly changing shape filled with a two-teal gradient, with a
  /// bright rim along its upper edge, like a pane of tinted glass.
  void _paintBlob(Canvas canvas, Offset c, double r, _Blob b, double t) {
    final phase = b.seed + t * 0.22;
    const n = 40;
    final points = <Offset>[
      for (var i = 0; i < n; i++)
        () {
          final a = 2 * math.pi * i / n;
          final k = 1 +
              0.09 * math.sin(3 * a + phase) +
              0.05 * math.sin(5 * a - phase * 1.4) +
              0.03 * math.cos(2 * a + phase * 0.7);
          return c + Offset(math.cos(a), math.sin(a)) * (r * k);
        }(),
    ];
    final path = _closedSmooth(points);
    final bounds = Rect.fromCircle(center: c, radius: r * 1.2);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            b.from.withValues(alpha: b.alpha),
            b.to.withValues(alpha: b.alpha * 0.8),
          ],
        ).createShader(bounds),
    );
    // Light across its top, fading down.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.35),
            AppColors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.6],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.white.withValues(alpha: 0.55),
    );
  }

  /// A wide ribbon sweeping across the screen, rippling gently.
  void _paintRibbon(Canvas canvas, Size size, double t) {
    final w = size.width, h = size.height;
    Path wave(double offset, double amp) {
      final path = Path();
      const steps = 36;
      for (var i = 0; i <= steps; i++) {
        final x = -0.1 * w + 1.2 * w * i / steps;
        final u = i / steps;
        final y = h * (0.6 - 0.2 * u) +
            offset +
            amp * math.sin(u * math.pi * 2.2 + t * 0.5) +
            amp * 0.4 * math.sin(u * math.pi * 5 - t * 0.35);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    final band = Rect.fromLTWH(0, h * 0.3, w, h * 0.4);
    canvas.drawPath(
      wave(0, h * 0.03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.13
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            AppColors.g1.withValues(alpha: 0.05),
            AppColors.g1.withValues(alpha: 0.32),
            AppColors.lavender.withValues(alpha: 0.4),
            AppColors.white.withValues(alpha: 0.08),
          ],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(band),
    );
    // A bright thread along its upper edge.
    canvas.drawPath(
      wave(-w * 0.055, h * 0.03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.white.withValues(alpha: 0.75),
    );
  }

  /// A rounded square of frosted glass, turned by [angle].
  static void _paintTile(Canvas canvas, Offset c, double side, double angle) {
    final rect =
        Rect.fromCenter(center: Offset.zero, width: side, height: side);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(side * 0.26));
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(angle);
    canvas.drawRRect(
      rr.shift(const Offset(0, 8)),
      Paint()
        ..color = AppColors.g2.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.62),
            AppColors.lavender.withValues(alpha: 0.32),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rr.deflate(0.7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.white.withValues(alpha: 0.9),
    );
    canvas.restore();
  }

  /// A sphere of tinted glass with a highlight and a bright rim.
  static void _paintSphere(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c + Offset(0, r * 0.25),
      r,
      Paint()
        ..color = AppColors.g2.withValues(alpha: 0.1)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: [
            AppColors.white.withValues(alpha: 0.95),
            AppColors.lavender.withValues(alpha: 0.55),
            AppColors.g1.withValues(alpha: 0.45),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.white.withValues(alpha: 0.9),
    );
  }

  /// A smooth closed curve through [points] (Catmull-Rom as Béziers).
  static Path _closedSmooth(List<Offset> points) {
    final n = points.length;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = points[(i - 1 + n) % n];
      final p1 = points[i];
      final p2 = points[(i + 1) % n];
      final p3 = points[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_AbstractPainter old) =>
      old.seconds != seconds || old.still != still || old.topInset != topInset;
}
