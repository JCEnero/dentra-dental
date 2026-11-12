import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../onboarding/widgets/visuals/tooth_glyph.dart';
import '../data/app_tour_steps.dart';

/// Decorates the spotlight [hole]: a soft teal glow outside it, a bright
/// glass rim, a ripple ring and a bobbing chevron pointing at it (from
/// below when [arrowBelow]). [motion] loops 0 → 1; it stays at 0 when
/// animations are off, which leaves a still ring.
class SpotlightPainter extends CustomPainter {
  SpotlightPainter({
    required this.hole,
    required this.motion,
    this.arrowBelow = false,
  }) : super(repaint: motion);

  final RRect hole;
  final Animation<double> motion;
  final bool arrowBelow;

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
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

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

    final bob = math.sin(t * 4 * math.pi) * 4;
    final dir = arrowBelow ? -1.0 : 1.0; // +1 points down
    final tip = Offset(
      hole.center.dx,
      arrowBelow ? hole.bottom + 30 - bob : hole.top - 30 + bob,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - 9, tip.dy - 9 * dir)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + 9, tip.dy - 9 * dir),
      stroke
        ..strokeWidth = 3
        ..color = AppColors.white.withValues(alpha: strength),
    );
  }

  @override
  bool shouldRepaint(SpotlightPainter old) =>
      old.hole != hole || old.arrowBelow != arrowBelow || old.motion != motion;
}

/// A small looping animation for each [TourSpot], drawn in a light teal
/// gradient on a white tile: what the feature does, in a second or two.
/// When [still],
/// it holds one finished-looking frame instead.
class FeatureGlyphPainter extends CustomPainter {
  FeatureGlyphPainter({
    required this.spot,
    required this.motion,
    this.still = false,
  }) : super(repaint: still ? null : motion);

  final TourSpot spot;
  final Animation<double> motion;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Glyph(canvas, size.center(Offset.zero), size.shortestSide,
        still ? 0.7 : motion.value);
    switch (spot) {
      case TourSpot.teeth:
        g.teeth();
      case TourSpot.treatment:
        g.treatment();
      case TourSpot.comparison:
        g.comparison();
      case TourSpot.rabi:
        g.rabi();
      case TourSpot.notifications:
        g.bell();
      case TourSpot.home:
        g.home();
      case TourSpot.scan:
        g.scan();
      case TourSpot.history:
        g.history();
      case TourSpot.clinics:
        g.clinics();
      case TourSpot.profile:
        g.profile();
    }
  }

  @override
  bool shouldRepaint(FeatureGlyphPainter old) =>
      old.spot != spot || old.still != still || old.motion != motion;
}

/// Draws one glyph on a unit grid centred on [c] (-0.5 → 0.5 of [s]),
/// in a light teal gradient for a white tile.
class _Glyph {
  _Glyph(this.canvas, this.c, this.s, this.t)
      : _bounds = Rect.fromCenter(center: c, width: s * 0.8, height: s * 0.8);

  final Canvas canvas;
  final Offset c;
  final double s;
  final double t;
  final Rect _bounds;

  static const _white = AppColors.white;

  Offset p(double x, double y) => Offset(c.dx + x * s, c.dy + y * s);

  /// Bright cyan-mint at the top left to medium teal at the bottom
  /// right, faded to [alpha].
  Shader _teal(double alpha) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.g1.withValues(alpha: alpha),
          AppColors.g2.withValues(alpha: alpha),
        ],
      ).createShader(_bounds);

  Paint stroke([double alpha = 1, double width = 0.055]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..shader = _teal(alpha);

  Paint fill([double alpha = 1]) => Paint()..shader = _teal(alpha);

  Paint solid(Color color, [double alpha = 1]) =>
      Paint()..color = color.withValues(alpha: alpha);

  /// A tooth turning on its axis above an orbit ring, like the 3D model.
  void teeth() {
    final angle = (t + 0.3) * 2 * math.pi;
    final turn = math.cos(angle);
    final orbit =
        Rect.fromCenter(center: p(0, 0.28), width: s * 0.68, height: s * 0.16);
    final dot = Offset(
      orbit.center.dx + orbit.width / 2 * math.sin(angle),
      orbit.center.dy + orbit.height / 2 * math.cos(angle),
    );
    final dotPaint = solid(AppColors.warmOrange);

    canvas.drawOval(orbit, stroke(0.45, 0.035));
    // The far half of the orbit passes behind the tooth.
    if (turn < 0) canvas.drawCircle(dot, s * 0.045, dotPaint);

    final pivot = p(0, -0.05);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.scale(math.max(turn.abs(), 0.12), 1);
    canvas.translate(-pivot.dx, -pivot.dy);
    final tooth = ToothGlyph.outline(ToothGlyph.rectAt(pivot, s * 0.42));
    // Front: white with a teal edge. Back: a soft teal fill.
    canvas.drawPath(tooth, turn > 0 ? solid(_white) : fill(0.35));
    canvas.drawPath(tooth, stroke(1, 0.05));
    canvas.restore();

    if (turn >= 0) canvas.drawCircle(dot, s * 0.045, dotPaint);
  }

  /// A clipboard whose steps tick off one by one.
  void treatment() {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p(0, 0.04), width: s * 0.52, height: s * 0.62),
        Radius.circular(s * 0.08),
      ),
      stroke(),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p(0, -0.27), width: s * 0.22, height: s * 0.1),
        Radius.circular(s * 0.03),
      ),
      fill(),
    );
    final fade = t > 0.9 ? (1 - t) / 0.1 : 1.0;
    for (var i = 0; i < 3; i++) {
      final y = -0.1 + i * 0.15;
      final done = ((t - 0.12 - i * 0.18) / 0.12).clamp(0.0, 1.0) * fade;
      canvas.drawLine(p(0.0, y), p(0.15, y), stroke(0.55, 0.045));
      final box = p(-0.12, y);
      canvas.drawCircle(box, s * 0.055, stroke(0.7, 0.032));
      if (done > 0) {
        paintCheckMark(
          canvas,
          box,
          s * 0.08 * Curves.easeOutBack.transform(done),
          AppColors.g2.withValues(alpha: done),
          strokeWidth: s * 0.045,
        );
      }
    }
  }

  /// Before/after: a slider sweeps across, whitening the tooth.
  void comparison() {
    final frame = Rect.fromCenter(center: c, width: s * 0.66, height: s * 0.56);
    final rr = RRect.fromRectAndRadius(frame, Radius.circular(s * 0.08));
    final split =
        frame.left + frame.width * (0.5 + 0.32 * math.sin(t * 2 * math.pi));
    final tooth = ToothGlyph.outline(ToothGlyph.rectAt(c, s * 0.3));

    // Before: a stained tooth on a tinted pane.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(frame.left, frame.top, split, frame.bottom));
    canvas.drawRRect(rr, fill(0.16));
    canvas.drawPath(tooth, solid(AppColors.warmOrange, 0.85));
    canvas.restore();

    // After: a bright white one.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(split, frame.top, frame.right, frame.bottom));
    canvas.drawPath(tooth, solid(_white));
    canvas.restore();

    canvas.drawPath(tooth, stroke(0.9, 0.035));
    canvas.drawRRect(rr, stroke(1, 0.04));
    canvas.drawLine(
        Offset(split, frame.top), Offset(split, frame.bottom), stroke(1, 0.04));
    final h = Offset(split, c.dy);
    canvas.drawCircle(h, s * 0.075, fill());
    final a = s * 0.025;
    canvas.drawPath(
      Path()
        ..moveTo(h.dx - a * 0.4, h.dy - a)
        ..lineTo(h.dx - a * 1.4, h.dy)
        ..lineTo(h.dx - a * 0.4, h.dy + a)
        ..moveTo(h.dx + a * 0.4, h.dy - a)
        ..lineTo(h.dx + a * 1.4, h.dy)
        ..lineTo(h.dx + a * 0.4, h.dy + a),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round
        ..color = _white,
    );
  }

  /// A chat bubble with Rabi typing, and an AI sparkle.
  void rabi() {
    final bubble = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: p(-0.03, -0.04), width: s * 0.62, height: s * 0.42),
        Radius.circular(s * 0.16),
      ))
      ..addPolygon([p(-0.2, 0.13), p(-0.27, 0.28), p(-0.05, 0.15)], true);
    canvas.drawPath(bubble, fill());
    for (var i = 0; i < 3; i++) {
      final phase = (t * 2 - i * 0.16) % 1;
      final lift = phase < 0.5 ? math.sin(phase * 2 * math.pi) : 0.0;
      canvas.drawCircle(
        p(-0.15 + i * 0.12, -0.04 - 0.06 * lift),
        s * 0.042,
        solid(_white),
      );
    }
    paintSparkle(canvas, p(0.31, -0.31),
        s * 0.1 * (0.7 + 0.3 * math.sin(t * 4 * math.pi)), AppColors.g1);
  }

  /// A bell that rings, then rests, with a new-item dot popping in.
  void bell() {
    final swing = math.sin(t * 6 * math.pi) * 0.35 * (t < 0.5 ? 1 - t * 2 : 0);
    final pivot = p(0, -0.3);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(swing);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawCircle(p(0, 0.24), s * 0.06, fill());
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s * 0.26, c.dy + s * 0.17)
        ..quadraticBezierTo(
            c.dx - s * 0.18, c.dy + s * 0.1, c.dx - s * 0.18, c.dy - s * 0.04)
        ..cubicTo(c.dx - s * 0.18, c.dy - s * 0.32, c.dx + s * 0.18,
            c.dy - s * 0.32, c.dx + s * 0.18, c.dy - s * 0.04)
        ..quadraticBezierTo(
            c.dx + s * 0.18, c.dy + s * 0.1, c.dx + s * 0.26, c.dy + s * 0.17)
        ..close(),
      fill(),
    );
    canvas.drawCircle(pivot, s * 0.04, fill());
    canvas.restore();

    final pop = ((t - 0.15) / 0.2).clamp(0.0, 1.0);
    if (pop > 0) {
      final badge = p(0.2, -0.2);
      final r = s * 0.085 * Curves.elasticOut.transform(pop);
      canvas.drawCircle(badge, r, solid(AppColors.coral));
      canvas.drawCircle(
        badge,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.03
          ..color = _white,
      );
    }
  }

  /// A house with a glowing window and smoke curling from the chimney.
  void home() {
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1;
      canvas.drawCircle(
        p(0.17 + 0.04 * math.sin(phase * 2 * math.pi), -0.27 - 0.17 * phase),
        s * (0.025 + 0.03 * phase),
        fill(0.6 * (1 - phase)),
      );
    }
    canvas.drawRect(Rect.fromPoints(p(0.13, -0.24), p(0.21, -0.1)), fill());
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s * 0.3, c.dy - s * 0.01)
        ..lineTo(c.dx, c.dy - s * 0.27)
        ..lineTo(c.dx + s * 0.3, c.dy - s * 0.01),
      stroke(1, 0.065),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(-0.21, -0.06), p(0.21, 0.27)),
        Radius.circular(s * 0.04),
      ),
      stroke(),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(-0.13, 0.08), p(-0.01, 0.27)),
        Radius.circular(s * 0.03),
      ),
      fill(),
    );
    final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    canvas.drawRect(Rect.fromPoints(p(0.05, 0.02), p(0.14, 0.11)),
        solid(AppColors.warmOrange, 0.35 + 0.65 * glow));
  }

  /// A viewfinder over a tooth, with a scan line sweeping up and down.
  void scan() {
    canvas.drawPath(
      ToothGlyph.outline(ToothGlyph.rectAt(p(0, 0.01), s * 0.36)),
      stroke(0.85, 0.045),
    );
    const k = 0.32;
    const len = 0.12;
    final corners = Path();
    for (final (sx, sy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      corners
        ..moveTo(c.dx + sx * k * s, c.dy + sy * (k - len) * s)
        ..lineTo(c.dx + sx * k * s, c.dy + sy * k * s)
        ..lineTo(c.dx + sx * (k - len) * s, c.dy + sy * k * s);
    }
    canvas.drawPath(corners, stroke(1, 0.055));

    final y = -0.24 + 0.48 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
    final line = p(0, y);
    final band =
        Rect.fromCenter(center: line, width: s * 0.52, height: s * 0.14);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.g1.withValues(alpha: 0),
            AppColors.g1.withValues(alpha: 0.35),
            AppColors.g1.withValues(alpha: 0),
          ],
        ).createShader(band),
    );
    canvas.drawLine(p(-0.26, y), p(0.26, y), stroke(1, 0.04));
  }

  /// A small chart whose bars grow in, one after another.
  void history() {
    const heights = [0.26, 0.42, 0.32, 0.5];
    final fade = t > 0.9 ? (1 - t) / 0.1 : 1.0;
    for (var i = 0; i < heights.length; i++) {
      final grow =
          Curves.easeOutBack.transform(((t - i * 0.07) / 0.3).clamp(0.0, 1.0)) *
              fade;
      final x = -0.21 + i * 0.14;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
              c.dx + (x - 0.045) * s,
              c.dy + (0.25 - heights[i] * grow) * s,
              c.dx + (x + 0.045) * s,
              c.dy + 0.25 * s),
          Radius.circular(s * 0.025),
        ),
        fill(i == heights.length - 1 ? 1 : 0.55),
      );
    }
    canvas.drawLine(p(-0.3, 0.28), p(0.3, 0.28), stroke(0.6, 0.04));
  }

  /// A map pin dropping in with a bounce, then a ripple where it lands.
  void clinics() {
    final drop = Curves.bounceOut.transform((t / 0.35).clamp(0.0, 1.0));
    final dy = -0.55 * (1 - drop) * s;
    if (t > 0.3) {
      final phase = ((t - 0.3) / 0.6).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: p(0, 0.3),
          width: s * (0.12 + 0.44 * phase),
          height: s * (0.04 + 0.13 * phase),
        ),
        stroke(1 - phase, 0.035),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: p(0, 0.3), width: s * 0.14, height: s * 0.05),
      fill(0.3 * drop),
    );
    final r = s * 0.17;
    final head = p(0, -0.09) + Offset(0, dy);
    final tip = Offset(head.dx, head.dy + r * 2.25);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..quadraticBezierTo(
            head.dx - r * 1.05, head.dy + r * 0.8, head.dx - r, head.dy)
        ..arcToPoint(Offset(head.dx + r, head.dy), radius: Radius.circular(r))
        ..quadraticBezierTo(
            head.dx + r * 1.05, head.dy + r * 0.8, tip.dx, tip.dy)
        ..close(),
      fill(),
    );
    canvas.drawCircle(head, r * 0.4, solid(_white));
  }

  /// An avatar whose profile ring fills up, then sparkles.
  void profile() {
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.27)));
    canvas.drawCircle(p(0, -0.07), s * 0.11, fill());
    canvas.drawOval(
      Rect.fromCenter(center: p(0, 0.27), width: s * 0.44, height: s * 0.32),
      fill(),
    );
    canvas.restore();

    final ring = Rect.fromCircle(center: c, radius: s * 0.35);
    canvas.drawCircle(c, s * 0.35, stroke(0.22, 0.05));
    final sweep = Curves.easeInOutCubic.transform((t / 0.6).clamp(0.0, 1.0));
    canvas.drawArc(ring, -math.pi / 2, 2 * math.pi * sweep, false, stroke());
    if (t > 0.6) {
      paintSparkle(
          canvas,
          p(0.31, -0.3),
          s *
              0.1 *
              Curves.elasticOut.transform(((t - 0.6) / 0.25).clamp(0.0, 1.0)),
          AppColors.warmOrange);
    }
  }
}

/// A one-shot burst of brand-coloured confetti from [origin], driven by
/// [progress] (0 → 1). Nothing is drawn before or after the burst.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({required this.progress, required this.origin})
      : super(repaint: progress);

  final Animation<double> progress;
  final Offset origin;

  static final List<_Piece> _pieces = _scatter();

  static List<_Piece> _scatter() {
    // Seeded, so the burst looks the same every time.
    final rnd = math.Random(11);
    const colors = [
      AppColors.g1,
      AppColors.g2,
      AppColors.coral,
      AppColors.warmOrange,
      AppColors.mintGreen,
      AppColors.white,
    ];
    return List.generate(48, (i) {
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.2;
      return _Piece(
        velocity: Offset(math.cos(angle), math.sin(angle)) *
            (420 + rnd.nextDouble() * 460),
        color: colors[i % colors.length],
        size: Size(5 + rnd.nextDouble() * 5, 3 + rnd.nextDouble() * 3),
        spin: (rnd.nextDouble() - 0.5) * 16,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0 || t == 1) return;
    const seconds = 1.7;
    final s = t * seconds;
    // Air drag slows the throw; gravity pulls the pieces down.
    final drift = (1 - math.exp(-2.4 * s)) / 2.4;
    final fall = 300 * s * s;
    final opacity = t < 0.7 ? 1.0 : (1 - t) / 0.3;

    for (final p in _pieces) {
      final pos = origin + p.velocity * drift + Offset(0, fall);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * s);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size.width, height: p.size.height),
          const Radius.circular(1.5),
        ),
        Paint()..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) =>
      old.origin != origin || old.progress != progress;
}

class _Piece {
  const _Piece({
    required this.velocity,
    required this.color,
    required this.size,
    required this.spin,
  });

  final Offset velocity;
  final Color color;
  final Size size;
  final double spin;
}
