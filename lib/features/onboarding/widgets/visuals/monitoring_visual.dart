import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'ambient_motion.dart';
import 'studio_stage.dart';
import 'tooth_illustration.dart';

/// Slide 4: three teeth receding along a timeline, past check-ins to the
/// latest, connected by a fine path that continues forward. It shows
/// continuity over time without any data or scores.
class MonitoringVisual extends StatelessWidget {
  const MonitoringVisual({super.key, required this.animate});

  final bool animate;

  /// Check-ins from oldest to latest: centre x, width, baseline y, opacity.
  static const List<({double x, double width, double base, double opacity})>
      _checkIns = [
    (x: 66, width: 56, base: 226, opacity: 0.45),
    (x: 132, width: 80, base: 232, opacity: 0.7),
    (x: 220, width: 128, base: 238, opacity: 1.0),
  ];

  @override
  Widget build(BuildContext context) {
    return AmbientMotion(
      active: animate,
      period: const Duration(milliseconds: 5600),
      restingValue: 0.25,
      builder: (context, t, _) {
        final lift = math.sin(t * 2 * math.pi);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const StudioStage(lightCenter: Offset(200, 150)),
            const CustomPaint(
              size: Size.square(kVisualCanvas),
              painter: _TimelinePainter(),
            ),
            for (final (i, c) in _checkIns.indexed)
              Positioned(
                left: c.x - c.width / 2,
                top: c.base -
                    c.width / ToothIllustration.aspectRatio -
                    // Only the latest tooth floats.
                    (i == _checkIns.length - 1 ? 8 + lift * 4 : 6),
                child: Opacity(
                  opacity: c.opacity,
                  child: ToothIllustration(width: c.width),
                ),
              ),
          ],
        );
      },
    );
  }
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
