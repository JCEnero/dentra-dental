import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_glass.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/dentra_note_card.dart';
import '../../../../shared/widgets/dentra_page_header.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../dental_explorer/geometry/dentition_builder.dart';
import '../../../dental_explorer/geometry/mesh.dart';
import '../../../dental_explorer/rendering/dentition_renderer.dart';
import '../../../dental_explorer/rendering/orbit_camera.dart';
import '../../rendering/scanner_model.dart';
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

/// The connected scanner: a floating 3D model on a glass stage, its name,
/// the few specs that matter, and the way into a scan.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ScannerStage(height: 184),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              header: true,
              child: Text(
                'Dentra Scan Pro',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Intraoral scanner · Synced just now',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _SpecGrid(),
          const SizedBox(height: 14),
          GlowButton(
            label: 'Start New Scan',
            icon: Icons.arrow_forward_rounded,
            intensity: 0.6,
            onTap: onStart,
          ),
        ],
      ),
    );
  }
}

/// Glass stage the scanner floats on, with its status on top.
class _ScannerStage extends StatelessWidget {
  const _ScannerStage({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(22));
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.white.withValues(alpha: 0.75),
              AppColors.lightLavender.withValues(alpha: 0.5),
            ],
          ),
          border: Border.all(color: AppGlass.border),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ExcludeSemantics(child: _ScannerView()),
              Positioned(
                left: 12,
                top: 12,
                child: Semantics(
                  label: 'Scanner connected',
                  excludeSemantics: true,
                  child: _GlassPill(
                    children: [
                      const _PulseDot(),
                      const SizedBox(width: 5),
                      Text('Connected', style: _pillText),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: _GlassPill(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.g2),
                    const SizedBox(width: 4),
                    Text('Calibrated', style: _pillText),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final TextStyle _pillText = GoogleFonts.outfit(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
  );
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppGlass.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Small "connected" dot with a halo that ripples out.
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
      dimension: 14,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 7 + 7 * t,
                height: 7 + 7 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      AppColors.successGreen.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The specs that matter: four small glass tiles, value first.
class _SpecGrid extends StatelessWidget {
  const _SpecGrid();

  static const _specs = [
    (Icons.center_focus_strong_outlined, 'RGB + NIR', 'Imaging · 850 nm'),
    (Icons.wifi_rounded, 'Wireless', 'Connection'),
    (Icons.battery_5_bar_rounded, '87%', 'Battery'),
    (Icons.memory_rounded, 'v2.4.1', 'Firmware'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tile(int i) {
      final (icon, value, label) = _specs[i];
      return Expanded(child: _SpecTile(icon: icon, value: value, label: label));
    }

    return Column(
      children: [
        Row(children: [tile(0), const SizedBox(width: 8), tile(1)]),
        const SizedBox(height: 8),
        Row(children: [tile(2), const SizedBox(width: 8), tile(3)]),
      ],
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.white.withValues(alpha: 0.5),
          border: Border.all(color: AppGlass.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightLavender,
              ),
              child: Icon(icon, size: 16, color: AppColors.g2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figureText(size: 14.5, weight: FontWeight.w800),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.secondaryText,
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
                          style: figureText(size: 12.5, color: AppColors.white),
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

// ── Scanner model ─────────────────────────────────────────────────

/// The 3D scanner, floating and turning gently while its light ring
/// breathes and a scan beam sweeps the surface below. Still under
/// reduced motion.
class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView>
    with SingleTickerProviderStateMixin {
  static const _period = 24.0; // seconds per loop of the motion

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_period * 1000).round()),
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = ScanMotion.reduced(context);
    if (_still) {
      _clock
        ..stop()
        ..value = 0;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => CustomPaint(
          painter: _ScannerPainter(t: _clock.value * _period, still: _still),
        ),
      ),
    );
  }
}

class _ScannerPainter extends CustomPainter {
  _ScannerPainter({required this.t, required this.still});

  /// Seconds into the motion loop.
  final double t;
  final bool still;

  static final _renderer = DentitionRenderer(ScannerModel.instance.model);
  static final SceneStyle _style = () {
    final s = SceneStyle()
      ..hideRoots = false
      ..rootReveal = 1;
    for (var o = 0; o < kOwnerCount; o++) {
      s.alpha[o] =
          o == ScannerModel.body || o == ScannerModel.light ? 1 : 0;
    }
    const teal = AppColors.g1;
    s
      ..tintR[ScannerModel.light] = teal.r
      ..tintG[ScannerModel.light] = teal.g
      ..tintB[ScannerModel.light] = teal.b
      ..tint[ScannerModel.light] = 0.5;
    return s;
  }();

  static double _wave(double t, double period) =>
      math.sin(2 * math.pi * t / period);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width, h = size.height;
    final scanner = ScannerModel.instance;
    final bob = still ? 0.0 : 1.5 * _wave(t, 3.6);
    final f = DentitionRenderer.focalLength(size);
    final pose = CameraPose(
      yaw: -0.55 + (still ? 0 : 0.42 * _wave(t, 12)),
      pitch: 0.22 + (still ? 0 : 0.05 * _wave(t, 8)),
      // Fit the wand's length across the width and its height in the
      // stage, whichever needs more room.
      distance: math.max(62 * f / (0.4 * w), 34 * f / (0.3 * h)),
      // Aiming a little below the wand lifts it, leaving room for the
      // beam under the pills' row.
      target: Vec3(0, -3 - bob, 0),
    );
    final floor = h * 0.86;

    // Soft glow behind, and the shadow it floats above.
    final glow = Rect.fromCircle(center: Offset(w / 2, h * 0.45), radius: w * 0.4);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.white.withValues(alpha: 0.8),
          AppColors.white.withValues(alpha: 0),
        ]).createShader(glow),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, floor),
        width: w * (0.46 - 0.02 * bob / 1.5),
        height: 10,
      ),
      Paint()
        ..color = AppColors.g2.withValues(alpha: 0.16 - 0.03 * bob / 1.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Scan beam from the window under the tip, with a line sweeping it.
    final from = _project(pose, size, f, scanner.window);
    if (from != null) {
      final to = Offset(from.dx + 4, floor - 2);
      final beam = Path()
        ..moveTo(from.dx - 4, from.dy)
        ..lineTo(from.dx + 4, from.dy)
        ..lineTo(to.dx + 28, to.dy)
        ..lineTo(to.dx - 28, to.dy)
        ..close();
      final breathe = still ? 0.7 : 0.6 + 0.4 * (0.5 + 0.5 * _wave(t, 2.4));
      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.g1.withValues(alpha: 0.38 * breathe),
              AppColors.g1.withValues(alpha: 0.06 * breathe),
            ],
          ).createShader(beam.getBounds()),
      );
      if (!still) {
        final k = (t % 1.6) / 1.6;
        final y = from.dy + (to.dy - from.dy) * k;
        final half = 4 + 24 * k;
        final x = from.dx + (to.dx - from.dx) * k;
        canvas.drawLine(
          Offset(x - half, y),
          Offset(x + half, y),
          Paint()
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color =
                AppColors.g2.withValues(alpha: 0.75 * math.sin(math.pi * k)),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(center: to, width: 64, height: 11),
        Paint()
          ..color = AppColors.g1.withValues(alpha: 0.3 * breathe)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // The light ring breathes.
    _style.glow[ScannerModel.light] =
        still ? 0.8 : 0.45 + 0.55 * (0.5 + 0.5 * _wave(t, 1.8));
    _renderer.paint(canvas, size, pose, _style);
  }

  /// Screen position of [p] for [pose] (see DentitionRenderer.paint).
  static Offset? _project(CameraPose pose, Size size, double f, Vec3 p) {
    final r = pose.rotation;
    final px = p.x - pose.target.x,
        py = p.y - pose.target.y,
        pz = p.z - pose.target.z;
    final d = pose.distance - (r[6] * px + r[7] * py + r[8] * pz);
    if (d < 4) return null;
    return Offset(
      size.width / 2 + (r[0] * px + r[1] * py + r[2] * pz) * f / d,
      size.height / 2 - (r[3] * px + r[4] * py + r[5] * pz) * f / d,
    );
  }

  @override
  bool shouldRepaint(_ScannerPainter old) => old.t != t || old.still != still;
}
