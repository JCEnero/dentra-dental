import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import 'scan_motion.dart';

/// One loop of the scan, as a fraction of the loop: along the outside of the
/// teeth, back along the inside, over the top, then a wave once it's done.
abstract class ReachSweep {
  static const double outerEnd = 0.34;
  static const double innerStart = 0.38;
  static const double innerEnd = 0.62;
  static const double topStart = 0.66;
  static const double topEnd = 0.90;
  static const double waveEnd = 0.945;

  /// A still picture for reduced motion: every side covered.
  static const double restful = 0.95;

  static double _progress(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  /// Where each pass has reached along the arch, -1 to 1.
  static double outer(double t) => -1 + 2 * _progress(t, 0, outerEnd);
  static double inner(double t) => 1 - 2 * _progress(t, innerStart, innerEnd);
  static double top(double t) => -1 + 2 * _progress(t, topStart, topEnd);

  /// How far the wave has spread from the front teeth to the back, 0-1.
  static double wave(double t) => _progress(t, topEnd, waveEnd);

  /// The covered teeth fading back to white before the next loop, 0-1.
  static double clearing(double t) => _progress(t, 0.96, 1);
}

/// How a scan covers the teeth: the words on top, then a line of light travelling
/// round an arch seen from above, along the outside, inside and top, with each
/// surface filling in behind it. Still, with every side covered, under reduced
/// motion.
class DeviceReachPanel extends StatefulWidget {
  const DeviceReachPanel({super.key});

  @override
  State<DeviceReachPanel> createState() => _DeviceReachPanelState();
}

class _DeviceReachPanelState extends State<DeviceReachPanel>
    with SingleTickerProviderStateMixin {
  static const double _diagramHeight = 190;

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ScanMotion.reduced(context)) {
      _sweep
        ..stop()
        ..value = ReachSweep.restful;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(26)),
      borderWidth: 1.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reaches every side of your teeth',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.2,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'The slim head goes around the outside, along the inside and '
                  'over the top of your teeth, so you won\'t need a mirror.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    height: 1.42,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: _diagramHeight,
            child: Semantics(
              image: true,
              label:
                  'An animated scan of a dental arch seen from above. A line '
                  'of light passes along the outside of the teeth, back along '
                  'the inside, then over the top, covering the front, cheek '
                  'sides, back molars, inner sides and biting surfaces.',
              child: RepaintBoundary(
                child: CustomPaint(painter: _ScanPainter(_sweep)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One pass of the scan line along the arch.
class _ScanPass {
  const _ScanPass({
    required this.at,
    required this.direction,
    required this.low,
    required this.high,
    required this.strength,
  });

  /// Where it has reached along the arch, and which way it's heading.
  final double at;
  final double direction;

  /// The band of the teeth it covers, as offsets outward from their middle.
  final double low;
  final double high;

  /// How visible it is, easing in and out at the ends of the pass.
  final double strength;
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.sweep) : super(repaint: sweep);

  final Animation<double> sweep;

  /// Teeth in the arch, and how far round the arch they reach (radians).
  static const int _teeth = 14;
  static const double _maxAngle = 1.75;

  // The arch, sized for a 290 x 190 canvas and sitting at its bottom.
  static const double _radiusX = 96;
  static const double _radiusY = 104;
  static const double _bottomMargin = 30;

  static double _edges(double t, double start, double end) {
    const ramp = 0.02;
    return math.min(
      ((t - start) / ramp).clamp(0.0, 1.0),
      ((end - t) / ramp).clamp(0.0, 1.0),
    );
  }

  static _ScanPass? _passAt(double t, double scale) {
    const edge = 25.0, gap = 3.0, middle = 11.0;
    if (t <= ReachSweep.outerEnd) {
      return _ScanPass(
        at: ReachSweep.outer(t),
        direction: 1,
        low: gap * scale,
        high: edge * scale,
        strength: _edges(t, 0, ReachSweep.outerEnd),
      );
    }
    if (t >= ReachSweep.innerStart && t <= ReachSweep.innerEnd) {
      return _ScanPass(
        at: ReachSweep.inner(t),
        direction: -1,
        low: -edge * scale,
        high: -gap * scale,
        strength: _edges(t, ReachSweep.innerStart, ReachSweep.innerEnd),
      );
    }
    if (t >= ReachSweep.topStart && t <= ReachSweep.topEnd) {
      return _ScanPass(
        at: ReachSweep.top(t),
        direction: 1,
        low: -middle * scale,
        high: middle * scale,
        strength: _edges(t, ReachSweep.topStart, ReachSweep.topEnd),
      );
    }
    return null;
  }

  /// How strongly a tooth at [u] is lit by the passing line or the final wave.
  static double _pulse(double u, double t, _ScanPass? pass) {
    if (pass != null) {
      final d = (u - pass.at) / 0.16;
      return math.exp(-d * d) * pass.strength;
    }
    final wave = ReachSweep.wave(t);
    if (wave <= 0 || wave >= 1) return 0;
    final d = (u.abs() - wave * 1.25) / 0.22;
    return math.exp(-d * d) * math.sin(math.pi * wave);
  }

  /// How covered a tooth is, from how far past it a pass has gone.
  static double _covered(double past) => (past / 0.14 + 0.5).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = sweep.value;
    final scale = math.min(size.height / 190, size.width / 290);
    final arch = _Arch(
      center: Offset(
        size.width / 2,
        size.height - (_bottomMargin + _radiusY) * scale,
      ),
      radiusX: _radiusX * scale,
      radiusY: _radiusY * scale,
      maxAngle: _maxAngle,
    );

    final pool = Rect.fromCircle(
      center: Offset(size.width / 2, size.height * 0.56),
      radius: size.height * 0.5,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g1.withValues(alpha: 0.2),
          AppColors.g1.withValues(alpha: 0),
        ]).createShader(pool),
    );

    final pass = _passAt(t, scale);
    final fade = 1 - ReachSweep.clearing(t);
    for (var i = 0; i < _teeth; i++) {
      final u = -1 + 2 * (i + 0.5) / _teeth;
      _paintTooth(
        canvas,
        arch,
        u,
        scale,
        outer: _covered(ReachSweep.outer(t) - u) * fade,
        inner: _covered(u - ReachSweep.inner(t)) * fade,
        top: _covered(ReachSweep.top(t) - u) * fade,
        pulse: _pulse(u, t, pass),
      );
    }

    if (pass != null) _paintScanLine(canvas, arch, pass, scale);
  }

  void _paintTooth(
    Canvas canvas,
    _Arch arch,
    double u,
    double scale, {
    required double outer,
    required double inner,
    required double top,
    required double pulse,
  }) {
    final reach = u.abs();
    final width = (18 + 5 * reach) * scale;
    final depth = (17 + 6 * reach) * scale;
    final at = arch.point(u, 0);

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(arch.outwardAngle(u) + math.pi / 2);
    // The tooth under the line lifts toward it.
    canvas.scale(1 + 0.14 * pulse);

    final tooth = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width, height: depth),
      Radius.circular(width * 0.38),
    );
    canvas.drawRRect(
      tooth.shift(Offset(0, 1.2 * scale)),
      Paint()
        ..color = const Color(0xFF17807D).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    if (pulse > 0.01) {
      canvas.drawRRect(
        tooth.inflate(3.5 * scale),
        Paint()..color = AppColors.g1.withValues(alpha: 0.38 * pulse),
      );
    }
    canvas.drawRRect(tooth, Paint()..color = AppColors.white);

    // Up in this frame is the outside of the arch.
    canvas.save();
    canvas.clipRRect(tooth);
    if (outer > 0) {
      canvas.drawRect(
        Rect.fromLTRB(-width, -depth, width, -depth * 0.17),
        Paint()..color = AppColors.g1.withValues(alpha: 0.8 * outer),
      );
    }
    if (inner > 0) {
      canvas.drawRect(
        Rect.fromLTRB(-width, depth * 0.17, width, depth),
        Paint()..color = AppColors.g1.withValues(alpha: 0.8 * inner),
      );
    }
    if (top > 0) {
      canvas.drawRect(
        Rect.fromLTRB(-width, -depth * 0.17, width, depth * 0.17),
        Paint()..color = AppColors.g2.withValues(alpha: 0.75 * top),
      );
    }
    canvas.restore();

    canvas.drawRRect(
      tooth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.g2.withValues(alpha: 0.3),
    );
    canvas.restore();
  }

  /// The line crossing the band it's scanning, with a glow around it and light
  /// trailing behind it along the arch.
  void _paintScanLine(Canvas canvas, _Arch arch, _ScanPass pass, double scale) {
    final middle = (pass.low + pass.high) / 2;

    const steps = 16;
    const span = 0.42;
    final trail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = pass.high - pass.low;
    for (var k = 0; k < steps; k++) {
      final from = pass.at - pass.direction * span * k / steps;
      final to = pass.at - pass.direction * span * (k + 1) / steps;
      if (from.abs() > 1 || to.abs() > 1) break;
      final left = 1 - k / steps;
      trail.color =
          AppColors.g1.withValues(alpha: 0.5 * left * left * pass.strength);
      canvas.drawLine(arch.point(from, middle), arch.point(to, middle), trail);
    }

    final center = arch.point(pass.at, middle);
    final glowRadius = 30 * scale;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g1.withValues(alpha: 0.5 * pass.strength),
          AppColors.g1.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    final reach = 3 * scale;
    final start = arch.point(pass.at, pass.low - reach);
    final end = arch.point(pass.at, pass.high + reach);
    Paint line(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = color;
    canvas.drawLine(
      start,
      end,
      line(6 * scale, AppColors.g2.withValues(alpha: 0.4 * pass.strength)),
    );
    canvas.drawLine(
      start,
      end,
      line(2.4 * scale, AppColors.white.withValues(alpha: pass.strength)),
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.sweep != sweep;
}

/// A U-shaped arch with the front teeth at the bottom. Positions along it run
/// from -1 to 1, offsets are outward from the middle of the teeth.
class _Arch {
  const _Arch({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.maxAngle,
  });

  final Offset center;
  final double radiusX;
  final double radiusY;
  final double maxAngle;

  double outwardAngle(double u) {
    final a = u * maxAngle;
    return math.atan2(math.cos(a) / radiusY, math.sin(a) / radiusX);
  }

  Offset point(double u, double offset) {
    final a = u * maxAngle;
    final out = outwardAngle(u);
    return Offset(
      center.dx + radiusX * math.sin(a) + offset * math.cos(out),
      center.dy + radiusY * math.cos(a) + offset * math.sin(out),
    );
  }
}
