import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../dental_explorer/geometry/mesh.dart';
import '../../scan/rendering/device_model.dart';
import '../../scan/rendering/device_renderer.dart';

/// A small how-to illustration. Its scan motion is not a detection signal.
class QrScanScene extends StatefulWidget {
  const QrScanScene(
      {super.key,
      this.confirmed = false,
      this.connected = false,
      this.paused = false,
      this.height = 138});
  final bool confirmed;
  final bool connected;
  final bool paused;
  final double height;
  @override
  State<QrScanScene> createState() => _QrScanSceneState();
}

class _QrScanSceneState extends State<QrScanScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4200));
  bool _still = false;
  void _sync() {
    _still = widget.paused ||
        widget.connected ||
        MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(QrScanScene old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: widget.connected
            ? 'Dentra Cam connected'
            : widget.confirmed
                ? 'Dentra Cam confirmed the setup code'
                : 'Illustration of the Dentra camera scanning a phone screen',
        child: RepaintBoundary(
            child: SizedBox(
                height: widget.height,
                child: CustomPaint(
                    painter: _ScenePainter(_motion,
                        still: _still,
                        confirmed: widget.confirmed,
                        connected: widget.connected)))),
      );
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.motion,
      {required this.still, required this.confirmed, required this.connected})
      : super(repaint: motion);
  final Animation<double> motion;
  final bool still, confirmed, connected;
  static final _renderer = DeviceRenderer(DeviceModel.instance);
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = still ? 0.4 : motion.value;
    final phone = Rect.fromCenter(
        center: Offset(size.width * .3, size.height * .5),
        width: size.height * .43,
        height: size.height * .82);
    final shell = RRect.fromRectAndRadius(phone, const Radius.circular(13));
    canvas.drawRRect(
        shell.shift(const Offset(3, 6)),
        Paint()
          ..color = AppColors.g2.withValues(alpha: .07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRRect(
        shell,
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.white.withValues(alpha: .95),
            AppColors.mintGreen.withValues(alpha: .55),
          ]).createShader(phone));
    canvas.drawRRect(
        shell,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final screen = phone.deflate(6);
    canvas.drawRRect(RRect.fromRectAndRadius(screen, const Radius.circular(8)),
        Paint()..color = Colors.white.withValues(alpha: .7));
    final notch = Rect.fromCenter(
        center: phone.topCenter + const Offset(0, 7), width: 14, height: 2);
    canvas.drawRRect(RRect.fromRectAndRadius(notch, const Radius.circular(2)),
        Paint()..color = AppColors.g2.withValues(alpha: .3));
    final code = Rect.fromCenter(
        center: screen.center,
        width: screen.width * .7,
        height: screen.width * .7);
    final ink = Paint()
      ..color = AppColors.g2.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (!confirmed && !connected) {
      // Low-contrast abstract mark, not another machine-readable setup QR.
      for (final point in [
        code.topLeft,
        code.topRight - const Offset(7, 0),
        code.bottomLeft - const Offset(0, 7)
      ]) {
        canvas.drawRect(point & const Size(7, 7), ink);
        canvas.drawRect((point + const Offset(2.5, 2.5)) & const Size(2, 2),
            Paint()..color = AppColors.g2.withValues(alpha: .28));
      }
      for (final d in const [
        Offset(10, 11),
        Offset(14, 10),
        Offset(10, 15),
        Offset(17, 15),
        Offset(14, 19)
      ]) {
        canvas.drawRect((code.topLeft + d) & const Size(2, 2),
            Paint()..color = AppColors.g2.withValues(alpha: .28));
      }
      final y = code.top +
          code.height * (still ? .5 : .5 - .5 * math.cos(t * math.pi * 2));
      canvas.drawLine(
          Offset(code.left - 3, y),
          Offset(code.right + 3, y),
          Paint()
            ..color = AppColors.g2.withValues(alpha: .55)
            ..strokeWidth = 1.5);
    } else {
      final c = code.center;
      canvas.drawPath(
          Path()
            ..moveTo(c.dx - 8, c.dy)
            ..lineTo(c.dx - 2, c.dy + 6)
            ..lineTo(c.dx + 10, c.dy - 7),
          Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round);
    }
    DevicePose pose(double focal, Offset center) => DevicePose(
        yaw: -.4,
        pitch: .15,
        roll: .55 + (still ? 0 : .025 * math.sin(t * math.pi * 2)),
        distance: 320,
        focal: focal,
        center: center);
    final bounds = _renderer.outline(pose(320, Offset.zero)).getBounds();
    final area = Rect.fromLTRB(size.width * .47, size.height * .05,
        size.width * .9, size.height * .96);
    final scale =
        math.min(area.width / bounds.width, area.height / bounds.height);
    final device = pose(320 * scale, area.center - bounds.center * scale);
    final lens = device.project(const Vec3(0, 76, 6));
    if (!connected) {
      canvas.drawPath(
          Path()
            ..moveTo(lens.dx, lens.dy)
            ..lineTo(screen.right, code.top - 3)
            ..lineTo(screen.right, code.bottom + 3)
            ..close(),
          Paint()
            ..shader = LinearGradient(colors: [
              AppColors.g2.withValues(alpha: confirmed ? .08 : .025),
              AppColors.g2.withValues(alpha: .01),
            ]).createShader(Rect.fromPoints(screen.center, lens)));
    }
    canvas.drawPath(
        _renderer.outline(device).shift(const Offset(3, 5)),
        Paint()
          ..color = AppColors.g2.withValues(alpha: .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    _renderer.paint(canvas, device);
    DeviceRenderer.paintParts(canvas, device,
        shine: still ? 0 : math.sin(t * math.pi * 2) * .1, switchOn: 1);
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.still != still ||
      old.confirmed != confirmed ||
      old.connected != connected;
}
