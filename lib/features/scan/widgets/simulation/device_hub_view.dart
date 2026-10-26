import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_glass.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/dentra_note_card.dart';
import '../../../../shared/widgets/dentra_page_header.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../scan_motion.dart';
import 'scan_sim_theme.dart';

/// Scan home: the (simulated) Dentra scanner, always connected and
/// ready, and the way into a new scan.
class DeviceHubView extends StatelessWidget {
  const DeviceHubView({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DentraPageHeader(title: 'Dental Scan'),
            Divider(height: 1, thickness: 1, color: AppGlass.divider),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Reveal(child: _DeviceCard(onStart: onStart)),
                      const SizedBox(height: 18),
                      const Reveal(
                        delay: Duration(milliseconds: 140),
                        child: _HowItWorks(),
                      ),
                      const SizedBox(height: 14),
                      const Reveal(
                        delay: Duration(milliseconds: 240),
                        child: DentraNoteCard(
                          icon: Icons.lightbulb_outline_rounded,
                          message: 'Find bright, even light and keep a small '
                              'mirror handy for the biting-surface and '
                              'back-of-teeth views.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      borderWidth: 1.5,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: 'Dentra Scanner connected and calibrated',
            excludeSemantics: true,
            child: Row(
              children: [
                const _PulseDot(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dentra Scanner Connected',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const _CalibratedBadge(),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Center(child: ExcludeSemantics(child: ScannerOrb(size: 184))),
          Text(
            'Dentra Scan Pro',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Intraoral imaging scanner · Paired',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          const _StatGrid(),
          const SizedBox(height: 18),
          GlowButton(
            label: 'Start New Scan',
            icon: Icons.arrow_forward_rounded,
            intensity: 0.85,
            onTap: onStart,
          ),
        ],
      ),
    );
  }
}

/// Green "connected" dot with a halo that keeps rippling out.
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ScanMotion.reduced(context)) {
      _pulse
        ..stop()
        ..value = 0.35;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 22,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 10 + 12 * t,
                height: 10 + 12 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HealthColors.healthy.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HealthColors.healthy,
                  boxShadow: [
                    BoxShadow(
                      color: HealthColors.healthy.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CalibratedBadge extends StatelessWidget {
  const _CalibratedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(
        color: HealthColors.healthy.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HealthColors.healthy.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded,
              size: 14, color: HealthColors.healthyInk),
          const SizedBox(width: 4),
          Text(
            'Calibrated',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: HealthColors.healthyInk,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Device readouts ───────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  const _StatGrid();

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 10);
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Battery',
                value: '87%',
                semantic: 'Battery 87 percent',
                hud: true,
                leading: _BatteryGlyph(level: 0.87),
              ),
            ),
            gap,
            Expanded(
              child: _StatTile(
                label: 'Signal',
                value: '4/4',
                semantic: 'Signal 4 of 4 bars',
                hud: true,
                leading: _SignalGlyph(bars: 4),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Firmware',
                value: 'v2.4.1',
                semantic: 'Firmware version 2.4.1',
                hud: true,
                leading: _IconGlyph(Icons.memory_rounded),
              ),
            ),
            gap,
            Expanded(
              child: _StatTile(
                label: 'Last sync',
                value: 'Just now',
                semantic: 'Last synced just now',
                leading: _IconGlyph(Icons.sync_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.semantic,
    required this.leading,
    this.hud = false,
  });

  final String label;
  final String value;
  final String semantic;
  final Widget leading;

  /// Numbers use the HUD face.
  final bool hud;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.white.withValues(alpha: 0.55),
          border: Border.all(color: AppGlass.border),
        ),
        child: Row(
          children: [
            SizedBox.square(dimension: 30, child: Center(child: leading)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: capsLabel()),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: hud
                          ? hudText(size: 14, weight: FontWeight.w700)
                          : GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconGlyph extends StatelessWidget {
  const _IconGlyph(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.lightLavender,
        border: Border.all(color: AppColors.lavender),
      ),
      child: Icon(icon, size: 17, color: AppColors.g2),
    );
  }
}

class _BatteryGlyph extends StatelessWidget {
  const _BatteryGlyph({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(28, 15), painter: _BatteryPainter(level));
}

class _BatteryPainter extends CustomPainter {
  const _BatteryPainter(this.level);
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width - 3, size.height),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.g2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 2.4, size.height * 0.3, 2.4,
            size.height * 0.4),
        const Radius.circular(1.2),
      ),
      Paint()..color = AppColors.g2,
    );
    final inner = body.deflate(2.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            inner.left, inner.top, inner.width * level, inner.height),
        const Radius.circular(2),
      ),
      Paint()..shader = AppColors.primaryGradient.createShader(inner.outerRect),
    );
  }

  @override
  bool shouldRepaint(_BatteryPainter old) => old.level != level;
}

class _SignalGlyph extends StatelessWidget {
  const _SignalGlyph({required this.bars});
  final int bars;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(24, 18), painter: _SignalPainter(bars));
}

class _SignalPainter extends CustomPainter {
  const _SignalPainter(this.bars);
  final int bars;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 4;
    const gap = 2.5;
    final w = (size.width - gap * (count - 1)) / count;
    for (var i = 0; i < count; i++) {
      final h = size.height * (0.35 + 0.65 * i / (count - 1));
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (w + gap), size.height - h, w, h),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = i < bars
              ? Color.lerp(AppColors.g1, AppColors.g2, i / (count - 1))!
              : AppColors.border,
      );
    }
  }

  @override
  bool shouldRepaint(_SignalPainter old) => old.bars != bars;
}

// ── How it works ──────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (
      'Capture 8 views',
      'Guided photos of every surface, including the tongue side.',
    ),
    (
      '3D reconstruction',
      'Your photos are mapped onto a 3D model of both arches.',
    ),
    (
      'Screening report',
      'A color-coded tooth map, findings and next steps.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SimSectionTitle('How it works'),
          const SizedBox(height: 12),
          for (var i = 0; i < _steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.cardGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.g1.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          '0${i + 1}',
                          style: hudText(
                            size: 11,
                            weight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.g1.withValues(alpha: 0.6),
                                  AppColors.g1.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _steps[i].$1,
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _steps[i].$2,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              height: 1.45,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Scanner orb ───────────────────────────────────────────────────

/// Glass orb holding the scanner wand, with orbit rings turning in 3D
/// and lights travelling along them. Still under reduced motion.
class ScannerOrb extends StatefulWidget {
  const ScannerOrb({super.key, this.size = 180});

  final double size;

  @override
  State<ScannerOrb> createState() => _ScannerOrbState();
}

class _ScannerOrbState extends State<ScannerOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ScanMotion.reduced(context)) {
      _spin
        ..stop()
        ..value = 0.12;
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, _) =>
              CustomPaint(painter: _OrbPainter(_spin.value)),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter(this.t);

  /// 0–1 over one full cycle.
  final double t;

  static const _rings = [
    // tilt (rad), squash, speed (turns per cycle), radius factor
    (-0.5, 0.32, 1.0, 0.92),
    (0.62, 0.26, -1.5, 0.82),
    (1.57, 0.2, 2.0, 0.72),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final a = t * 2 * math.pi;

    // Halo.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.g1.withValues(alpha: 0.32),
            AppColors.g1.withValues(alpha: 0.1),
            AppColors.g1.withValues(alpha: 0),
          ],
          stops: const [0.25, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Tick ring, turning slowly.
    final tick = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final ang = i / 60 * 2 * math.pi + a * 0.25;
      final long = i % 5 == 0;
      final d = Offset(math.cos(ang), math.sin(ang));
      tick.color = AppColors.g2.withValues(alpha: long ? 0.45 : 0.18);
      canvas.drawLine(
          c + d * (r * 0.97), c + d * (r * (long ? 0.9 : 0.93)), tick);
    }

    // Back halves of the rings, behind the orb.
    for (final ring in _rings) {
      _ring(canvas, c, r, ring, a, front: false);
    }

    _orb(canvas, c, r * 0.4);

    // Front halves and their travelling lights.
    for (final ring in _rings) {
      _ring(canvas, c, r, ring, a, front: true);
    }
  }

  void _ring(Canvas canvas, Offset c, double r,
      (double, double, double, double) ring, double a,
      {required bool front}) {
    final (tilt, squash, speed, k) = ring;
    final rx = r * k, ry = r * k * squash;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    // The rings precess slowly so the orb reads as turning in 3D.
    canvas.rotate(tilt + math.sin(a + tilt) * 0.12);
    final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    canvas.drawArc(
      rect,
      front ? 0 : math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = front ? 1.6 : 1.1
        ..color = AppColors.g2.withValues(alpha: front ? 0.55 : 0.22),
    );
    // Light on the ring: drawn on whichever half it is on.
    final phi = a * speed + tilt;
    final onFront = math.sin(phi) >= 0;
    if (onFront == front) {
      final p = Offset(rx * math.cos(phi), ry * math.sin(phi));
      canvas.drawCircle(
        p,
        front ? 7 : 5,
        Paint()
          ..color = AppColors.g1.withValues(alpha: front ? 0.45 : 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(p, front ? 2.6 : 1.8,
          Paint()..color = front ? AppColors.white : AppColors.lavender);
    }
    canvas.restore();
  }

  void _orb(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c.translate(0, 3),
      r,
      Paint()
        ..color = AppColors.g2.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [AppColors.white, Color(0xFFE6F9F7), Color(0xFFB9ECE6)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.white,
    );
    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(-r * 0.3, -r * 0.45),
          width: r * 0.8,
          height: r * 0.36),
      Paint()..color = AppColors.white.withValues(alpha: 0.7),
    );
    _wand(canvas, c, r);
  }

  /// A slim intraoral scanner, angled, with its scan light on.
  void _wand(Canvas canvas, Offset c, double r) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-math.pi / 4);
    final len = r * 1.5;
    final half = r * 0.16;

    // Light cone from the head.
    final head = Offset(len * 0.42, 0);
    final cone = Path()
      ..moveTo(head.dx, head.dy - half * 0.4)
      ..lineTo(head.dx + r * 0.42, head.dy - half * 1.6)
      ..lineTo(head.dx + r * 0.42, head.dy + half * 1.6)
      ..lineTo(head.dx, head.dy + half * 0.4)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.g1.withValues(alpha: 0.55),
            AppColors.g1.withValues(alpha: 0),
          ],
        ).createShader(cone.getBounds()),
    );

    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-len / 2, -half, len * 0.6, half * 2),
        Radius.circular(half),
      ))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-len / 2 + len * 0.55, -half * 0.6, len * 0.3,
            half * 1.2),
        Radius.circular(half * 0.6),
      ))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(len * 0.26, -half * 0.85, len * 0.18, half * 1.7),
        Radius.circular(half * 0.7),
      ));
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.white, Color(0xFFDDE7E6)],
        ).createShader(body.getBounds()),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.navy.withValues(alpha: 0.2),
    );
    // Status light and lens.
    canvas.drawCircle(Offset(-len * 0.12, 0), half * 0.42,
        Paint()..color = HealthColors.healthy);
    canvas.drawCircle(Offset(len * 0.35, 0), half * 0.45,
        Paint()..color = AppColors.navy.withValues(alpha: 0.8));
    canvas.drawCircle(Offset(len * 0.35, 0), half * 0.2,
        Paint()..color = AppColors.g1);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}
