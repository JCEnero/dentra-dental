import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'ambient_motion.dart';
import 'mascot.dart';
import 'studio_props.dart';
import 'studio_stage.dart';
import 'tooth_illustration.dart';

/// Slide 3: past check-ins recede along a timeline toward the latest one,
/// where the mascot hops and cheers under falling confetti and a check
/// badge. A dashed path continues forward. It shows continuity over time
/// without any data or scores.
class MonitoringVisual extends StatelessWidget {
  const MonitoringVisual({super.key, required this.animate});

  final bool animate;

  /// Check-ins from oldest to latest: centre x, width, baseline y, opacity.
  /// The latest is the mascot; its width is the mascot's.
  static const List<({double x, double width, double base, double opacity})>
      _checkIns = [
    (x: 62, width: 56, base: 226, opacity: 0.45),
    (x: 128, width: 80, base: 232, opacity: 0.7),
    (x: 230, width: 118, base: 238, opacity: 1.0),
  ];

  @override
  Widget build(BuildContext context) {
    final latest = _checkIns.last;
    return AmbientMotion(
      active: animate,
      period: const Duration(milliseconds: 5600),
      // Grounded between hops, arms up: a complete frame when motion is off.
      restingValue: 0.7,
      builder: (context, t, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const StudioStage(lightCenter: Offset(200, 150)),
            const CustomPaint(
              size: Size.square(kVisualCanvas),
              painter: _TimelinePainter(),
            ),
            for (final c in _checkIns.take(_checkIns.length - 1))
              Positioned(
                left: c.x - c.width / 2,
                top: c.base - c.width / ToothIllustration.aspectRatio - 6,
                child: Opacity(
                  opacity: c.opacity,
                  child: ToothIllustration(width: c.width),
                ),
              ),
            CustomPaint(
              size: const Size.square(kVisualCanvas),
              painter: _CelebrationPainter(t: t, front: false),
            ),
            Positioned.fromRect(
              rect: Mascot.rectStandingAt(
                Offset(latest.x, latest.base + 10),
                latest.width,
              ),
              child: Mascot(width: latest.width, rig: MascotRig.cheer(t)),
            ),
            CustomPaint(
              size: const Size.square(kVisualCanvas),
              painter: _CelebrationPainter(t: t, front: true),
            ),
          ],
        );
      },
    );
  }
}

/// Confetti and sparkles around the latest check-in, plus a check badge that
/// pops gently with each hop.
class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter({required this.t, required this.front});

  final double t;
  final bool front;

  @override
  void paint(Canvas canvas, Size size) {
    if (!front) {
      StudioProps.confetti(
          canvas, const Rect.fromLTWH(150, 4, 160, 200), t, count: 14);
      for (final (at, r, phase) in const [
        (Offset(40, 150), 6.0, 0.0),
        (Offset(98, 96), 4.5, 0.5),
        (Offset(300, 100), 5.0, 0.25),
      ]) {
        final twinkle = 0.5 + 0.5 * math.sin((t * 2 + phase) * 2 * math.pi);
        StudioProps.sparkle(
          canvas,
          at,
          r * (0.45 + 0.55 * twinkle),
          opacity: 0.35 + 0.65 * twinkle,
        );
      }
      return;
    }

    final pop = math.sin(t * 4 * math.pi).abs();
    const badge = Offset(150, 84);
    // Expanding halo once per loop.
    final ring = t;
    canvas.drawCircle(
      badge,
      15 + ring * 16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.white.withValues(alpha: 0.6 * (1 - ring)),
    );
    StudioProps.checkBadge(
      canvas,
      badge.translate(0, -pop * 3),
      14 + pop * 1.2,
    );
    StudioProps.confetti(
        canvas, const Rect.fromLTWH(170, 0, 130, 230), (t + 0.5) % 1.0,
        count: 6);
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) =>
      old.t != t || old.front != front;
}

/// A gentle path through the base of each check-in that continues beyond the
/// latest one as a dashed line (the journey ahead).
class _TimelinePainter extends CustomPainter {
  const _TimelinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = [
      for (final c in MonitoringVisual._checkIns) Offset(c.x, c.base + 14),
    ];

    final travelled = Path()
      ..moveTo(18, nodes.first.dy - 6)
      ..quadraticBezierTo(40, nodes.first.dy, nodes[0].dx, nodes[0].dy)
      ..quadraticBezierTo(
        (nodes[0].dx + nodes[1].dx) / 2,
        nodes[0].dy + 8,
        nodes[1].dx,
        nodes[1].dy,
      )
      ..quadraticBezierTo(
        (nodes[1].dx + nodes[2].dx) / 2,
        nodes[1].dy + 8,
        nodes[2].dx,
        nodes[2].dy,
      );
    canvas.drawPath(
      travelled,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.white.withValues(alpha: 0.75),
    );

    // Dashed continuation toward the right edge.
    final dash = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.white.withValues(alpha: 0.45);
    for (var x = nodes.last.dx + 14; x < size.width - 10; x += 9) {
      final y = nodes.last.dy - (x - nodes.last.dx) * 0.12;
      canvas.drawLine(Offset(x, y), Offset(x + 4, y - 0.5), dash);
    }

    for (final (i, node) in nodes.indexed) {
      final isLatest = i == nodes.length - 1;
      if (isLatest) {
        canvas.drawCircle(
          node,
          11,
          Paint()..color = AppColors.white.withValues(alpha: 0.22),
        );
        canvas.drawCircle(node, 5.5, Paint()..color = AppColors.white);
      } else {
        canvas.drawCircle(node, 4, Paint()..color = AppColors.g2);
        canvas.drawCircle(
          node,
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = AppColors.white.withValues(alpha: 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => false;
}
