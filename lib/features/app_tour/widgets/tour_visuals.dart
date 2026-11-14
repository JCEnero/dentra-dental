import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/constants/app_colors.dart';
import '../../onboarding/widgets/visuals/tooth_glyph.dart';

/// Decorates the spotlight [hole]: a soft teal glow outside it, a bright
/// glass rim and a ripple ring. [motion] loops 0 → 1; it stays at 0 when
/// animations are off, which leaves a still ring.
class SpotlightPainter extends CustomPainter {
  SpotlightPainter({required this.hole, required this.motion})
      : super(repaint: motion);

  final RRect hole;
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    // While the lens grows from nothing, the decorations fade in.
    final strength = (hole.outerRect.shortestSide / 56).clamp(0.0, 1.0);
    if (strength == 0) return;
    final t = motion.value;

    // Glow stays outside the lens, so the target itself stays crisp.
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(hole),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = AppColors.g1.withValues(alpha: 0.55 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawRRect(
      hole,
      stroke..color = AppColors.white.withValues(alpha: 0.95 * strength),
    );

    // Two ripples per loop, spreading out and fading.
    final ripple = (t * 2) % 1;
    canvas.drawRRect(
      hole.inflate(4 + 16 * ripple),
      stroke
        ..strokeWidth = 2
        ..color =
            AppColors.white.withValues(alpha: 0.7 * (1 - ripple) * strength),
    );
  }

  @override
  bool shouldRepaint(SpotlightPainter old) =>
      old.hole != hole || old.motion != motion;
}

/// The intro's abstract backdrop: soft panes of teal and mint glass that
/// slowly change shape in the corners, kept clear of the middle where the
/// words and buttons sit. Fades in over the first part of [enter]. Holds
/// still under reduced motion.
class TourIntroBackdrop extends StatefulWidget {
  const TourIntroBackdrop({super.key, required this.enter});

  final Animation<double> enter;

  @override
  State<TourIntroBackdrop> createState() => _TourIntroBackdropState();
}

class _TourIntroBackdropState extends State<TourIntroBackdrop>
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
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _BackdropPainter(_seconds, widget.enter, _still),
          ),
        ),
      ),
    );
  }
}

/// One pane: where its centre sits (fractions of the screen), its size (a
/// fraction of the shorter side), its two colours and strength, and its own
/// beat so no two move together.
class _Pane {
  const _Pane(
      this.x, this.y, this.r, this.from, this.to, this.alpha, this.seed);

  final double x, y, r;
  final Color from, to;
  final double alpha;
  final double seed;
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.seconds, this.enter, this.still)
      : super(repaint: Listenable.merge([seconds, enter]));

  final ValueNotifier<double> seconds;
  final Animation<double> enter;
  final bool still;

  static const _panes = [
    // Top right, the largest, mostly off screen.
    _Pane(1.02, 0.05, 0.5, AppColors.g1, AppColors.g2, 0.24, 0.0),
    // Bottom left.
    _Pane(
        -0.04, 0.95, 0.42, AppColors.mintGreen, AppColors.cardSolid, 0.26, 1.9),
    // A small one low on the right.
    _Pane(0.97, 0.8, 0.11, AppColors.lavender, AppColors.g1, 0.42, 3.4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = still ? 0.0 : seconds.value;
    final fade = still
        ? 1.0
        : Curves.easeOutCubic.transform((enter.value / 0.4).clamp(0.0, 1.0));
    if (fade <= 0) return;
    // Sized from the shorter side so a wide window keeps them in the
    // corners.
    final unit = math.min(size.width, size.height * 0.62);
    for (final p in _panes) {
      final drift = Offset(
        6 * math.sin(t * 0.21 + p.seed),
        8 * math.cos(t * 0.17 + p.seed),
      );
      _pane(
        canvas,
        Offset(p.x * size.width, p.y * size.height) + drift,
        p.r * unit,
        p,
        t,
        fade,
      );
    }
  }

  /// A soft, slowly changing shape filled with a two-teal gradient, light
  /// along its top and a bright rim, like a pane of tinted glass.
  void _pane(
      Canvas canvas, Offset c, double r, _Pane p, double t, double fade) {
    final phase = p.seed + t * 0.2;
    const n = 40;
    final points = <Offset>[
      for (var i = 0; i < n; i++)
        () {
          final a = 2 * math.pi * i / n;
          final k = 1 +
              0.08 * math.sin(3 * a + phase) +
              0.05 * math.sin(5 * a - phase * 1.3) +
              0.03 * math.cos(2 * a + phase * 0.7);
          return c + Offset(math.cos(a), math.sin(a)) * (r * k);
        }(),
    ];
    final path = _closedSmooth(points);
    final bounds = Rect.fromCircle(center: c, radius: r * 1.15);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.from.withValues(alpha: p.alpha * fade),
            p.to.withValues(alpha: p.alpha * 0.75 * fade),
          ],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.4 * fade),
            AppColors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.6],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = AppColors.white.withValues(alpha: 0.7 * fade),
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
  bool shouldRepaint(_BackdropPainter old) =>
      old.seconds != seconds || old.enter != enter || old.still != still;
}

/// The send-off's burst behind Rabi, centred on [center]: a halo that
/// swells in and breathes, two rings and a ring of short rays that pop out
/// as he lands, and sparkles that twinkle round him.
///
/// [enter] runs 0 → 1 once as the send-off appears; [loop] repeats 0 → 1.
/// When [still], it draws the settled picture with nothing moving.
class CelebrationPainter extends CustomPainter {
  CelebrationPainter({
    required this.enter,
    required this.loop,
    required this.center,
    required this.radius,
    this.still = false,
  }) : super(repaint: Listenable.merge([enter, loop]));

  final Animation<double> enter;
  final Animation<double> loop;
  final Offset center;

  /// The halo's size; the rest is laid out from it.
  final double radius;
  final bool still;

  /// Where each sparkle sits round him: angle (degrees from the right,
  /// clockwise), distance as a part of [radius], size, and colour.
  static const _sparkles = [
    (-150.0, 0.98, 0.15, AppColors.g1),
    (-35.0, 1.02, 0.12, AppColors.g2),
    (-95.0, 1.12, 0.08, AppColors.cardSolid),
    (170.0, 0.92, 0.09, AppColors.g2),
    (12.0, 0.9, 0.1, AppColors.g1),
    (-65.0, 0.78, 0.06, AppColors.g1),
  ];

  static double _span(double t, double from, double length) =>
      ((t - from) / length).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final e = still ? 1.0 : enter.value;
    final l = still ? 0.0 : loop.value;
    final r = radius;

    // The halo: white at the heart, mint at the edge, breathing slowly.
    final swell = Curves.easeOutBack.transform(_span(e, 0.08, 0.4));
    if (swell > 0) {
      final hr = r * swell * (1 + 0.035 * math.sin(l * 2 * math.pi));
      final rect = Rect.fromCircle(center: center, radius: hr);
      canvas.drawCircle(
        center,
        hr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.white.withValues(alpha: 0.95),
              AppColors.mintGreen.withValues(alpha: 0.55),
              AppColors.mintGreen.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(rect),
      );
    }
    if (still) {
      _paintSparkles(canvas, 1, 0);
      return;
    }

    // Two rings ripple out as he lands.
    for (var i = 0; i < 2; i++) {
      final p = _span(e, 0.2 + i * 0.09, 0.42);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        center,
        r * (0.45 + 0.75 * Curves.easeOutCubic.transform(p)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + 3 * (1 - p)
          ..color = AppColors.g1.withValues(alpha: 0.7 * (1 - p)),
      );
    }

    // A ring of short rays shooting out and shrinking: the pop.
    final pop = _span(e, 0.22, 0.34);
    if (pop > 0 && pop < 1) {
      final out = Curves.easeOutCubic.transform(pop);
      final ray = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.4;
      for (var i = 0; i < 12; i++) {
        final a = (i * 30 + 15) * math.pi / 180;
        final dir = Offset(math.cos(a), math.sin(a));
        final from = r * (0.62 + 0.42 * out);
        final length = r * 0.2 * (1 - pop);
        canvas.drawLine(
          center + dir * from,
          center + dir * (from + length),
          ray
            ..color = (i.isEven ? AppColors.g1 : AppColors.g2)
                .withValues(alpha: 1 - pop * pop),
        );
      }
    }

    _paintSparkles(canvas, e, l);
  }

  /// Sparkles spring in one after another, then twinkle out of step.
  void _paintSparkles(Canvas canvas, double e, double l) {
    for (var i = 0; i < _sparkles.length; i++) {
      final (deg, at, big, color) = _sparkles[i];
      final grow = still
          ? 1.0
          : Curves.elasticOut.transform(_span(e, 0.36 + i * 0.05, 0.4));
      if (grow <= 0) continue;
      final twinkle =
          still ? 1.0 : 0.62 + 0.38 * math.sin((l + i / 6) * 4 * math.pi).abs();
      final a = deg * math.pi / 180;
      paintSparkle(
        canvas,
        center + Offset(math.cos(a), math.sin(a)) * (radius * at),
        radius * big * grow * twinkle,
        color,
      );
    }
  }

  @override
  bool shouldRepaint(CelebrationPainter old) =>
      old.center != center ||
      old.radius != radius ||
      old.still != still ||
      old.enter != enter ||
      old.loop != loop;
}

/// Confetti fired from both lower corners, up and in across the screen,
/// then fluttering down: each piece flips over as it falls and drifts from
/// side to side. Driven by [progress] (0 → 1); nothing is drawn before or
/// after the volley.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  /// How long the volley lasts, to match its controller.
  static const Duration duration = Duration(milliseconds: 3400);

  static final List<_Piece> _pieces = _scatter();

  static List<_Piece> _scatter() {
    // Seeded, so the volley looks the same every time.
    final rnd = math.Random(7);
    const colors = [
      AppColors.g1,
      AppColors.g2,
      AppColors.cardSolid,
      AppColors.mintGreen,
      Color(0xFF17807D), // the guides' deep teal
    ];
    return List.generate(88, (i) {
      final fromLeft = i.isEven;
      // Aimed steeply up and fanned wide, at mixed speeds, so the pieces
      // spread over the whole screen instead of meeting in the middle.
      final aim = fromLeft ? -0.4 * math.pi : -0.6 * math.pi;
      final angle = aim + (rnd.nextDouble() - 0.5) * 0.9;
      final pick = rnd.nextDouble();
      return _Piece(
        fromLeft: fromLeft,
        direction: Offset(math.cos(angle), math.sin(angle)),
        speed: 0.7 + rnd.nextDouble() * 0.8,
        delay: rnd.nextDouble() * 0.2,
        color: colors[rnd.nextInt(colors.length)],
        // Mostly ribbons and dots, a few sparkles.
        shape: pick < 0.48
            ? _Shape.ribbon
            : pick < 0.82
                ? _Shape.dot
                : _Shape.sparkle,
        size: 4.5 + rnd.nextDouble() * 4,
        spin: (rnd.nextDouble() - 0.5) * 9,
        flip: 5 + rnd.nextDouble() * 7,
        sway: rnd.nextDouble() * 2 * math.pi,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0 || t == 1) return;
    final seconds = t * duration.inMilliseconds / 1000;
    // Sized to the screen, so the volley fills a tablet as well as a phone.
    final k = size.height / 820;
    final opacity = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    // Air slows the throw toward a gentle falling speed.
    const drag = 2.1;
    final settle = 150 * k;

    for (final p in _pieces) {
      final s = seconds - p.delay;
      if (s <= 0) continue;
      final slowed = (1 - math.exp(-drag * s)) / drag;
      final v = p.direction * (p.speed * 1000 * k);
      final origin =
          Offset(p.fromLeft ? -8 : size.width + 8, size.height * 0.84);
      final sway =
          math.sin(s * 3.6 + p.sway) * 20 * k * (1 - math.exp(-1.4 * s));
      final pos = origin +
          Offset(
            v.dx * slowed + sway,
            settle * s + (v.dy - settle) * slowed,
          );
      final paint = Paint()..color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * s);
      switch (p.shape) {
        case _Shape.ribbon:
          // Flipping over: seen edge-on it narrows to a line.
          canvas.scale(1, math.cos(p.flip * s).abs().clamp(0.15, 1.0));
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: p.size * 2, height: p.size * 0.8),
              const Radius.circular(1.5),
            ),
            paint,
          );
        case _Shape.dot:
          canvas.scale(math.cos(p.flip * s).abs().clamp(0.3, 1.0), 1);
          canvas.drawCircle(Offset.zero, p.size * 0.55, paint);
        case _Shape.sparkle:
          paintSparkle(canvas, Offset.zero, p.size * 0.95, paint.color);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.progress != progress;
}

enum _Shape { ribbon, dot, sparkle }

class _Piece {
  const _Piece({
    required this.fromLeft,
    required this.direction,
    required this.speed,
    required this.delay,
    required this.color,
    required this.shape,
    required this.size,
    required this.spin,
    required this.flip,
    required this.sway,
  });

  final bool fromLeft;
  final Offset direction;
  final double speed;

  /// Seconds after the volley starts that this piece leaves.
  final double delay;
  final Color color;
  final _Shape shape;
  final double size;
  final double spin;

  /// How fast it turns over as it falls.
  final double flip;

  /// Where in its side-to-side drift it starts.
  final double sway;
}
