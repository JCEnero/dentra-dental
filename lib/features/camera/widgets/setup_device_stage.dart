import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/guide_kit.dart' show guideAccent;
import '../../dental_explorer/geometry/mesh.dart';
import '../../scan/rendering/device_model.dart';
import '../../scan/rendering/device_renderer.dart';
import '../camera_strings.dart';

/// What the setup guide shows the Dentra Cam doing. Each is a how-to
/// picture, never the camera's real state.
enum DeviceScene {
  /// A USB-C cable plugging into its base.
  charging,

  /// Turned to show the power switch on its side, which lights up and
  /// slides on.
  power,

  /// Sending out its own Wi-Fi network, beside the name to look for.
  hotspot,
}

/// The Dentra Cam, as the 3D model the scan page uses, on a glass stage.
/// Holds still when the device asks for reduced motion.
class SetupDeviceStage extends StatefulWidget {
  const SetupDeviceStage({super.key, required this.scene, this.height});

  final DeviceScene scene;

  /// The stage's height. By default it takes about a third of the screen.
  final double? height;

  @override
  State<SetupDeviceStage> createState() => _SetupDeviceStageState();
}

class _SetupDeviceStageState extends State<SetupDeviceStage>
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
    final height = widget.height ??
        (MediaQuery.sizeOf(context).height * 0.32).clamp(200.0, 280.0);
    final label = GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: guideAccent,
    );
    return Semantics(
      image: true,
      label: switch (widget.scene) {
        DeviceScene.charging => CamText.artCharging,
        DeviceScene.power => CamText.artPower,
        DeviceScene.hotspot => CamText.artHotspot,
      },
      excludeSemantics: true,
      child: GlassCard(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        borderWidth: 1.4,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _StagePainter(
                    scene: widget.scene,
                    seconds: _seconds,
                    still: _still,
                    label: label,
                  ),
                ),
              ),
              // On the right half, shrunk to fit with large text.
              if (widget.scene == DeviceScene.hotspot)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerRight,
                    widthFactor: 0.56,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _NetworkRow(seconds: _seconds, still: _still),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How the camera's network shows in a phone's Wi-Fi list: a white row
/// with its name, sliding in as the waves reach it.
class _NetworkRow extends StatelessWidget {
  const _NetworkRow({required this.seconds, required this.still});

  final ValueListenable<double> seconds;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final name = GoogleFonts.outfit(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: AppColors.navy,
    );
    final radius = BorderRadius.circular(16);
    final row = DecoratedBox(
      // Soft teal lift under the glass, kept faint so the pill floats.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.g2.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: GlassBlur(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            decoration: setupClearGlass(radius),
            child: _label(name),
          ),
        ),
      ),
    );
    if (still) return row;
    return AnimatedBuilder(
      animation: seconds,
      builder: (context, child) {
        final t = Curves.easeOutBack
            .transform(((seconds.value - 0.5) / 0.6).clamp(0.0, 1.0));
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(18 * (1 - t), 0),
            child: child,
          ),
        );
      },
      child: row,
    );
  }

  Widget _label(TextStyle name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_rounded, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: CamText.product, style: name),
              TextSpan(
                text: ' ····',
                style: name.copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Clear glass for the setup guide's small surfaces (the ready list, the
/// camera's Wi-Fi row): a thin white sheen fading toward mint, with a
/// bright rim, so the backdrop shows through instead of a white slab.
BoxDecoration setupClearGlass(BorderRadius radius) {
  return BoxDecoration(
    borderRadius: radius,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.white.withValues(alpha: 0.42),
        AppColors.lightLavender.withValues(alpha: 0.16),
      ],
    ),
    border: Border.all(color: AppColors.white.withValues(alpha: 0.8)),
  );
}

// ── The stage ────────────────────────────────────────────────────────

final _renderer = DeviceRenderer(DeviceModel.instance);

/// How the device stands in each scene.
class _Hold {
  const _Hold({
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.area,
  });

  final double yaw;
  final double pitch;
  final double roll;

  /// Where it fits on the stage, as fractions of its width and height.
  final Rect area;

  static const charging = _Hold(
    yaw: -0.42,
    pitch: 0.3,
    roll: 0.62,
    area: Rect.fromLTRB(0.12, 0.05, 0.76, 0.74),
  );

  static const power = _Hold(
    yaw: -1.02,
    pitch: 0.2,
    roll: 1.02,
    area: Rect.fromLTRB(0.03, 0.06, 0.80, 0.94),
  );

  static const hotspot = _Hold(
    yaw: -0.42,
    pitch: 0.3,
    roll: -0.62,
    area: Rect.fromLTRB(0.02, 0.1, 0.44, 0.97),
  );

  static _Hold of(DeviceScene scene) => switch (scene) {
        DeviceScene.charging => charging,
        DeviceScene.power => power,
        DeviceScene.hotspot => hotspot,
      };
}

const double _distance = 320;

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.scene,
    required this.seconds,
    required this.still,
    required this.label,
  }) : super(repaint: seconds);

  final DeviceScene scene;
  final ValueListenable<double> seconds;
  final bool still;
  final TextStyle label;

  /// The device's outline at one pixel per millimetre, per scene: what the
  /// fit is worked out from.
  static final Map<DeviceScene, Rect> _bounds = {};

  static DevicePose _pose(_Hold hold, double focal, Offset center,
          {double yaw = 0, double pitch = 0}) =>
      DevicePose(
        yaw: hold.yaw + yaw,
        pitch: hold.pitch + pitch,
        roll: hold.roll,
        distance: _distance,
        focal: focal,
        center: center,
      );

  /// The pose that fits the device in its area of a stage of [size].
  DevicePose _fit(Size size,
      {double yaw = 0, double pitch = 0, double bob = 0}) {
    final hold = _Hold.of(scene);
    final unit = _bounds[scene] ??=
        _renderer.outline(_pose(hold, _distance, Offset.zero)).getBounds();
    final area = Rect.fromLTRB(
      hold.area.left * size.width,
      hold.area.top * size.height,
      hold.area.right * size.width,
      hold.area.bottom * size.height,
    );
    final k = math.min(area.width / unit.width, area.height / unit.height);
    return _pose(
      hold,
      _distance * k,
      area.center - unit.center * k + Offset(0, bob),
      yaw: yaw,
      pitch: pitch,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final clock = still ? 0.0 : seconds.value;
    final sway = still ? 0.0 : math.sin(clock * 0.5);
    final pose = _fit(
      size,
      yaw: 0.08 * sway,
      pitch: still ? 0 : 0.02 * math.sin(clock * 0.37),
      bob: still ? 0 : 2.5 * math.sin(clock * 0.8),
    );
    final mm = pose.focal / _distance;

    _paintLight(canvas, size, pose);
    _paintShadow(canvas, pose);
    switch (scene) {
      case DeviceScene.charging:
        _paintCable(canvas, size, pose, mm, _plugIn(clock));
        _renderer.paint(canvas, pose);
        DeviceRenderer.paintParts(canvas, pose, shine: sway);
        _paintPortLabel(canvas, size, pose, mm, clock);
      case DeviceScene.power:
        _renderer.paint(canvas, pose);
        _paintSwitchGlow(canvas, pose, clock);
        DeviceRenderer.paintParts(canvas, pose,
            shine: sway, switchOn: _switchOn(clock));
        _paintSwitchLabel(canvas, size, pose, clock);
      case DeviceScene.hotspot:
        _renderer.paint(canvas, pose);
        DeviceRenderer.paintParts(canvas, pose, shine: sway);
        _paintWaves(canvas, size, pose, mm, clock);
    }
  }

  /// Light pooled on the glass behind the device, and a teal glow at the
  /// bottom of the stage.
  void _paintLight(Canvas canvas, Size size, DevicePose pose) {
    final pool = Rect.fromCircle(
      center: Offset(size.width * 0.7, size.height * 1.05),
      radius: size.height * 0.95,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g1.withValues(alpha: 0.2),
          AppColors.g1.withValues(alpha: 0),
        ]).createShader(pool),
    );
    final middle = pose.project(const Vec3(0, 0, 0));
    final light = Rect.fromCircle(center: middle, radius: size.height * 0.62);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.white.withValues(alpha: 0.9),
          AppColors.white.withValues(alpha: 0),
        ]).createShader(light),
    );
  }

  void _paintShadow(Canvas canvas, DevicePose pose) {
    canvas.drawPath(
      _renderer.outline(pose).shift(const Offset(10, 14)),
      Paint()
        ..color = const Color(0xFF17807D).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  /// A line out from a part at [from], [reach] across, to a short [text]
  /// in the direction [toward], kept on the stage.
  void _paintLabel(Canvas canvas, Size size, Offset from, double reach,
      Offset toward, String text) {
    final out = _unit(toward);
    final start = from + out * (reach + 9);
    final end = from + out * (reach + 9 + 30);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.g2.withValues(alpha: 0.75),
    );
    canvas.drawCircle(end, 3, Paint()..color = AppColors.g2);
    final painter = TextPainter(
      text: TextSpan(text: text, style: label),
      textDirection: TextDirection.ltr,
    )..layout();
    var at = out.dx < 0
        ? end + Offset(-6 - painter.width, -painter.height / 2)
        : end + Offset(6, -painter.height / 2);
    at = Offset(
      at.dx.clamp(8.0, size.width - painter.width - 8),
      at.dy.clamp(8.0, size.height - painter.height - 8),
    );
    painter.paint(canvas, at);
  }

  static Offset _unit(Offset v) {
    final d = v.distance;
    return d == 0 ? Offset.zero : v / d;
  }

  // ── Charging ──────────────────────────────────────────────────────

  static const double _plugLoop = 5.4;

  /// How far in the plug is: out, slides in, stays a while, comes out.
  double _plugIn(double clock) {
    if (still) return 1;
    final t = clock % _plugLoop;
    if (t < 0.7) return 0;
    if (t < 1.25) return Curves.easeOutCubic.transform((t - 0.7) / 0.55);
    if (t < 4.7) return 1;
    if (t < 5.1) return 1 - Curves.easeInCubic.transform((t - 4.7) / 0.4);
    return 0;
  }

  /// The base's port on screen, and the way out of it.
  (Offset, Offset) _port(DevicePose pose) {
    final base = pose.project(const Vec3(0, DeviceModel.baseY, 0));
    final above = pose.project(const Vec3(0, DeviceModel.baseY + 20, 0));
    return (base, _unit(base - above));
  }

  /// The USB-C plug and its cable, out over the stage's bottom edge. [plug]
  /// is how far in the plug is.
  void _paintCable(
      Canvas canvas, Size size, DevicePose pose, double mm, double plug) {
    final (base, down) = _port(pose);
    final gap = (1 - plug) * 16 * mm;
    final tip = base + down * gap;

    final width = (4.4 * mm).clamp(5.0, 10.0);
    final plugEnd = tip + down * (13 * mm);
    // Down out of the base, then back along the bottom of the stage and
    // off its left edge.
    final end = Offset(-width * 2, size.height * 0.9);
    final cable = Path()
      ..moveTo(plugEnd.dx, plugEnd.dy)
      ..cubicTo(
        plugEnd.dx + down.dx * 30 * mm,
        plugEnd.dy + down.dy * 30 * mm,
        size.width * 0.62,
        size.height * 1.02,
        size.width * 0.3,
        size.height * 0.93,
      )
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.88,
        end.dx,
        end.dy,
      );

    canvas.drawPath(
      cable.shift(const Offset(4, 7)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = AppColors.navy.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      cable,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD3E1E2),
    );
    canvas.drawPath(
      cable.shift(Offset(-width * 0.16, -width * 0.16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.42
        ..strokeCap = StrokeCap.round
        ..color = AppColors.white.withValues(alpha: 0.95),
    );

    // The plug: a metal tip, a white housing and a teal collar.
    final plugW = 8.2 * mm, plugL = 13 * mm;
    canvas
      ..save()
      ..translate(tip.dx, tip.dy)
      ..rotate(math.atan2(down.dy, down.dx) - math.pi / 2);
    if (gap > 0.5) {
      // Out of the port, its metal tip shows.
      final metal =
          Rect.fromLTWH(-plugW * 0.32, -4.5 * mm, plugW * 0.64, 6.5 * mm);
      canvas.drawRRect(
        RRect.fromRectAndRadius(metal, Radius.circular(1.2 * mm)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFE6ECEC), Color(0xFF94A7AB), Color(0xFFDDE5E5)],
          ).createShader(metal),
      );
    }
    final housing = RRect.fromRectAndRadius(
      Rect.fromLTWH(-plugW / 2, 1.5 * mm, plugW, plugL),
      Radius.circular(2.4 * mm),
    );
    canvas.drawRRect(
      housing,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFCFDCDD)],
        ).createShader(housing.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-plugW / 2, 1.5 * mm, plugW, 2.6 * mm),
        Radius.circular(1.2 * mm),
      ),
      Paint()..color = AppColors.g2,
    );
    canvas.restore();
  }

  /// A ring where the plug clicks in, and the "USB-C" label on the port.
  void _paintPortLabel(
      Canvas canvas, Size size, DevicePose pose, double mm, double clock) {
    final (base, down) = _port(pose);
    final t = clock % _plugLoop;
    if (!still && t > 1.2 && t < 2.1) {
      final p = (t - 1.2) / 0.9;
      canvas.drawCircle(
        base,
        8 * mm + 26 * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.g1.withValues(alpha: 0.8 * (1 - p)),
      );
    }
    // Out to the side of the base that faces the open stage.
    final side = Offset(-down.dy, down.dx);
    final away = side.dx > 0 ? side : -side;
    _paintLabel(canvas, size, base + down * (8 * mm), 6 * mm,
        away + const Offset(0, -0.35), CamText.usbLabel);
  }

  // ── Power ─────────────────────────────────────────────────────────

  static const double _loop = 4.8;

  /// The switch slides on, stays on a while, then resets.
  double _switchOn(double clock) {
    if (still) return 1;
    final t = clock % _loop;
    if (t < 1.0) return 0;
    if (t < 1.45) return Curves.easeOutBack.transform((t - 1.0) / 0.45);
    if (t < 4.1) return 1;
    if (t < 4.4) return 1 - Curves.easeInOut.transform((t - 4.1) / 0.3);
    return 0;
  }

  /// The switch on screen: its centre, and how far its corners reach.
  (Offset, double) _switchOnScreen(DevicePose pose) {
    final f = DeviceRenderer.switchFrame;
    final r = f.right * (DeviceArt.switchSize.width / 2);
    final u = f.up * (DeviceArt.switchSize.height / 2);
    final c = pose.project(f.center);
    final reach = [
      pose.project(f.center - r + u),
      pose.project(f.center + r + u),
      pose.project(f.center + r - u),
      pose.project(f.center - r - u),
    ].map((p) => (p - c).distance).reduce(math.max);
    return (c, reach);
  }

  /// A teal glow on the shell under the switch, brighter as it clicks on.
  void _paintSwitchGlow(Canvas canvas, DevicePose pose, double clock) {
    final (c, reach) = _switchOnScreen(pose);
    final t = clock % _loop;
    final click =
        still ? 0.0 : (t > 1.3 && t < 2.1 ? 1 - (t - 1.3) / 0.8 : 0.0);
    final r = reach * (1.9 + 0.6 * click);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g1.withValues(alpha: 0.6 + 0.3 * click),
          AppColors.g1.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  /// Rings round the switch, and the "Power" label.
  void _paintSwitchLabel(
      Canvas canvas, Size size, DevicePose pose, double clock) {
    final (c, reach) = _switchOnScreen(pose);
    canvas
      ..drawCircle(
        c,
        reach + 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.white.withValues(alpha: 0.95),
      )
      ..drawCircle(
        c,
        reach + 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.g2.withValues(alpha: 0.6),
      );
    if (!still) {
      for (final shift in const [0.0, 0.5]) {
        final p = (clock / 1.8 + shift) % 1;
        canvas.drawCircle(
          c,
          reach + 6 + 22 * p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.g1.withValues(alpha: 0.75 * (1 - p)),
        );
      }
    }
    final axisAt = pose.project(const Vec3(0, -30, 0));
    // Out from the device, leaning toward the empty top right.
    final out = _unit(_unit(c - axisAt) + const Offset(0.9, -0.6));
    _paintLabel(canvas, size, c, reach, out, CamText.powerSwitchLabel);
  }

  // ── Hotspot ───────────────────────────────────────────────────────

  /// Wi-Fi waves rolling out of the head toward the network row.
  void _paintWaves(
      Canvas canvas, Size size, DevicePose pose, double mm, double clock) {
    final head = pose.project(const Vec3(0, DeviceModel.headY, 0));
    // Aimed at the network row, on the right of the stage.
    final target = Offset(size.width * 0.66, size.height * 0.5);
    final aim = math.atan2(target.dy - head.dy, target.dx - head.dx);
    const spread = 0.7;
    final reach = (target - head).distance * 0.7;
    for (var i = 0; i < 3; i++) {
      final p = still ? (i + 1) / 3.6 : (clock / 2.2 + i / 3) % 1;
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: 12 * mm + reach * p),
        aim - spread / 2,
        spread,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = AppColors.g2
              .withValues(alpha: 0.75 * math.sin(p * math.pi).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.scene != scene ||
      old.seconds != seconds ||
      old.still != still ||
      old.label != label;
}
