import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../scan/rendering/device_model.dart';
import '../../scan/rendering/device_renderer.dart';

/// The real Dentra camera mesh, softly floating beside a Wi-Fi tile.
/// This is an illustration, not a simulated device connection status.
class CameraConnectionArt extends StatefulWidget {
  const CameraConnectionArt({super.key, this.connected = false});

  final bool connected;

  @override
  State<CameraConnectionArt> createState() => _CameraConnectionArtState();
}

class _CameraConnectionArtState extends State<CameraConnectionArt>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  final _renderer = DeviceRenderer(DeviceModel.instance);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: '3D illustration of the Dentra camera',
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _ConnectionPainter(
                  motion: _motion,
                  renderer: _renderer,
                  connected: widget.connected,
                  still: MediaQuery.disableAnimationsOf(context),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ConnectionPainter extends CustomPainter {
  _ConnectionPainter({
    required this.motion,
    required this.renderer,
    required this.connected,
    required this.still,
  }) : super(repaint: motion);

  final Animation<double> motion;
  final DeviceRenderer renderer;
  final bool connected;
  final bool still;

  DevicePose _pose(double focal, Offset center, double time) => DevicePose(
        yaw: -.48 + .16 * math.sin(time),
        pitch: .24 + .025 * math.cos(time),
        roll: -.52,
        distance: 320,
        focal: focal,
        center: center,
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = still ? 0.0 : motion.value * math.pi * 2;
    final center = Offset(size.width * .47, size.height * .46);
    final halo = Rect.fromCenter(
        center: center, width: size.width * .72, height: size.height * .94);
    canvas.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: .8),
          AppColors.mintGreen.withValues(alpha: .16),
          AppColors.mintGreen.withValues(alpha: 0),
        ]).createShader(halo),
    );
    final floor = Rect.fromCenter(
      center: Offset(size.width * .47, size.height * .91),
      width: 106 - 7 * math.sin(time),
      height: 12,
    );
    canvas.drawOval(
      floor,
      Paint()
        ..color = const Color(0xFF23766F).withValues(alpha: .12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final orbit = Rect.fromCenter(
        center: Offset(size.width * .49, size.height * .71),
        width: size.width * .64,
        height: size.height * .29);
    canvas.drawArc(
      orbit,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = AppColors.g2.withValues(alpha: .14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Fit the same physical model used in the scan view into this small hero.
    final outline = renderer.outline(_pose(320, Offset.zero, 0)).getBounds();
    final scale = math.min(
        size.width * .53 / outline.width, size.height * .86 / outline.height);
    final pose = _pose(320 * scale,
        center - outline.center * scale + Offset(0, math.sin(time) * 3), time);
    renderer.paint(canvas, pose);
    DeviceRenderer.paintParts(canvas, pose, shine: math.sin(time), switchOn: 1);

    final tileCenter =
        Offset(size.width * .76, size.height * .36 - math.sin(time + .6) * 3);
    final tile = RRect.fromRectAndRadius(
        Rect.fromCenter(center: tileCenter, width: 56, height: 56),
        const Radius.circular(18));
    canvas.drawRRect(
      tile.shift(const Offset(0, 8)),
      Paint()
        ..color = AppColors.g2.withValues(alpha: .12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFFFF), Color(0xFFDAF0EC)],
        ).createShader(tile.outerRect),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..color = Colors.white.withValues(alpha: .95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final line = Paint()
      ..color = const Color(0xFF247B73)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    if (connected) {
      canvas.drawPath(
          Path()
            ..moveTo(tileCenter.dx - 10, tileCenter.dy)
            ..lineTo(tileCenter.dx - 3, tileCenter.dy + 7)
            ..lineTo(tileCenter.dx + 11, tileCenter.dy - 8),
          line);
    } else {
      final origin = tileCenter + const Offset(0, 10);
      for (final radius in [10.0, 17.0, 24.0]) {
        canvas.drawArc(Rect.fromCircle(center: origin, radius: radius),
            -math.pi * .75, math.pi * .5, false, line);
      }
      canvas.drawCircle(origin, 1.8, Paint()..color = line.color);
    }
  }

  @override
  bool shouldRepaint(_ConnectionPainter old) =>
      connected != old.connected || still != old.still;
}
