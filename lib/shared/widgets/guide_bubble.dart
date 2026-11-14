import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'dentra_glass_ui.dart' show dentraMotion;
import 'glass_card.dart' show GlassBlur;

/// Which side of a [GuideBubble] its tail leaves from.
enum BubbleTail { none, top, bottom, left, right }

/// Rabi's speech bubble: frosted glass with a soft rim, rounded all the way
/// round, and a small curved tail that points at him. The tail slides along
/// its edge when [tailAt] changes.
class GuideBubble extends StatelessWidget {
  const GuideBubble({
    super.key,
    required this.child,
    this.tail = BubbleTail.none,
    this.tailAt = 0.5,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 15),
  });

  final Widget child;
  final BubbleTail tail;

  /// Where the tail sits along its edge: 0 at the left or top end, 1 at the
  /// right or bottom end.
  final double tailAt;
  final EdgeInsets padding;

  /// How far the tail reaches out of the bubble.
  static const double tailLength = 11;
  static const double _radius = 22;
  static const double _tailHalf = 11;

  /// The bubble's outline in a box of [size].
  static Path outline(Size size, BubbleTail tail, double at) {
    final body = Rect.fromLTRB(
      tail == BubbleTail.left ? tailLength : 0,
      tail == BubbleTail.top ? tailLength : 0,
      size.width - (tail == BubbleTail.right ? tailLength : 0),
      size.height - (tail == BubbleTail.bottom ? tailLength : 0),
    );
    final r = math.min(_radius, body.shortestSide / 2);
    final shape = Path()
      ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(r)));
    if (tail == BubbleTail.none) return shape;

    // The tail's root, the way it points, and the way its base runs.
    final across = tail == BubbleTail.top || tail == BubbleTail.bottom;
    final room = (across ? body.width : body.height) - 2 * (r + _tailHalf);
    final along = r + _tailHalf + math.max(0.0, room) * at.clamp(0.0, 1.0);
    final (Offset root, Offset out, Offset run) = switch (tail) {
      BubbleTail.top => (
          Offset(body.left + along, body.top),
          const Offset(0, -1),
          const Offset(1, 0),
        ),
      BubbleTail.bottom => (
          Offset(body.left + along, body.bottom),
          const Offset(0, 1),
          const Offset(1, 0),
        ),
      BubbleTail.left => (
          Offset(body.left, body.top + along),
          const Offset(-1, 0),
          const Offset(0, 1),
        ),
      _ => (
          Offset(body.right, body.top + along),
          const Offset(1, 0),
          const Offset(0, 1),
        ),
    };
    Offset at2(double u, double v) => root + run * u + out * v;
    // Starts just inside the bubble so the two shapes join without a seam.
    final start = at2(-_tailHalf, -1);
    final c1 = at2(-_tailHalf * 0.36, 0);
    final tipA = at2(-1.7, tailLength - 2.6);
    final tip = at2(0, tailLength + 0.4);
    final tipB = at2(1.7, tailLength - 2.6);
    final c2 = at2(_tailHalf * 0.36, 0);
    final end = at2(_tailHalf, -1);
    final spike = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(c1.dx, c1.dy, tipA.dx, tipA.dy)
      ..quadraticBezierTo(tip.dx, tip.dy, tipB.dx, tipB.dy)
      ..quadraticBezierTo(c2.dx, c2.dy, end.dx, end.dy)
      ..close();
    return Path.combine(PathOperation.union, shape, spike);
  }

  /// Where the tail is, for the pop-in to grow from.
  Alignment _origin() => switch (tail) {
        BubbleTail.top => Alignment(tailAt * 2 - 1, -1),
        BubbleTail.bottom => Alignment(tailAt * 2 - 1, 1),
        BubbleTail.left => Alignment(-1, tailAt * 2 - 1),
        BubbleTail.right => Alignment(1, tailAt * 2 - 1),
        BubbleTail.none => Alignment.center,
      };

  @override
  Widget build(BuildContext context) {
    final inset = EdgeInsets.only(
      left: tail == BubbleTail.left ? tailLength : 0,
      top: tail == BubbleTail.top ? tailLength : 0,
      right: tail == BubbleTail.right ? tailLength : 0,
      bottom: tail == BubbleTail.bottom ? tailLength : 0,
    );
    // Pops out of Rabi's side once, when it first appears.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: dentraMotion(context, 520),
      curve: Curves.easeOutBack,
      builder: (context, pop, bubble) => Transform.scale(
        scale: 0.86 + 0.14 * pop,
        alignment: _origin(),
        child: Opacity(opacity: pop.clamp(0.0, 1.0), child: bubble),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: tailAt),
        duration: dentraMotion(context, 460),
        curve: Curves.easeInOutCubic,
        builder: (context, at, content) => CustomPaint(
          painter: _BubbleShadow(tail, at),
          child: ClipPath(
            clipper: _BubbleClip(tail, at),
            child: GlassBlur(
              strong: true,
              child: CustomPaint(
                painter: _BubbleGlass(tail, at),
                foregroundPainter: _BubbleRim(tail, at),
                child: content,
              ),
            ),
          ),
        ),
        child: Padding(padding: padding + inset, child: child),
      ),
    );
  }
}

class _BubbleClip extends CustomClipper<Path> {
  const _BubbleClip(this.tail, this.at);

  final BubbleTail tail;
  final double at;

  @override
  Path getClip(Size size) => GuideBubble.outline(size, tail, at);

  @override
  bool shouldReclip(_BubbleClip old) => old.tail != tail || old.at != at;
}

/// Depth under the bubble: a wide teal haze and a tight contact shadow,
/// both only outside it (under see-through glass a shadow would show as a
/// grey band).
class _BubbleShadow extends CustomPainter {
  const _BubbleShadow(this.tail, this.at);

  final BubbleTail tail;
  final double at;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = GuideBubble.outline(size, tail, at);
    canvas
      ..save()
      ..clipPath(Path.combine(
        PathOperation.difference,
        Path()..addRect((Offset.zero & size).inflate(60)),
        shape,
      ))
      ..drawPath(
        shape.shift(const Offset(0, 12)),
        Paint()
          ..color = AppColors.g2.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      )
      ..drawPath(
        shape.shift(const Offset(0, 3)),
        Paint()
          ..color = AppColors.navy.withValues(alpha: 0.07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BubbleShadow old) => old.tail != tail || old.at != at;
}

/// The glass: a bright fill that cools to mint, a mint glow in the far
/// corner, and a glossy reflection across the top.
class _BubbleGlass extends CustomPainter {
  const _BubbleGlass(this.tail, this.at);

  final BubbleTail tail;
  final double at;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shape = GuideBubble.outline(size, tail, at);
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // Nearly opaque on web, which has no blur behind it.
            AppColors.white.withValues(alpha: kIsWeb ? 0.96 : 0.88),
            AppColors.lightLavender.withValues(alpha: kIsWeb ? 0.92 : 0.70),
          ],
        ).createShader(bounds),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.05, 1.1),
          radius: 0.95,
          colors: [
            AppColors.g1.withValues(alpha: 0.2),
            AppColors.g1.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
    // The reflection: a soft white band over the upper part, fading down.
    final gloss = Rect.fromLTWH(
      -size.width * 0.1,
      -size.height * 0.55,
      size.width * 1.2,
      size.height * 1.0,
    );
    canvas.drawOval(
      gloss,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.0),
            AppColors.white.withValues(alpha: 0.55),
          ],
        ).createShader(gloss),
    );
  }

  @override
  bool shouldRepaint(_BubbleGlass old) => old.tail != tail || old.at != at;
}

/// The rim, over everything: bright white where the light hits, glowing
/// teal on the far side.
class _BubbleRim extends CustomPainter {
  const _BubbleRim(this.tail, this.at);

  final BubbleTail tail;
  final double at;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shape = GuideBubble.outline(size, tail, at);
    final light = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.white,
        AppColors.white.withValues(alpha: 0.5),
        AppColors.g1.withValues(alpha: 0.9),
      ],
      stops: const [0, 0.45, 1],
    ).createShader(bounds);
    canvas
      // A soft inner glow along the edge…
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.white.withValues(alpha: 0.55),
              AppColors.white.withValues(alpha: 0),
              AppColors.g1.withValues(alpha: 0.28),
            ],
          ).createShader(bounds)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      // …and the crisp line itself (half of it is clipped away).
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..shader = light,
      );
  }

  @override
  bool shouldRepaint(_BubbleRim old) => old.tail != tail || old.at != at;
}
