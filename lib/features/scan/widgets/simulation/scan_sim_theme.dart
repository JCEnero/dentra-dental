import 'dart:math' as math;
import 'dart:ui' show FontFeature, PathMetric;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/mock_scan_report.dart';
import '../scan_motion.dart';

// Shared look for the scan simulation: status colours from the brand
// palette, figures in the app font, the glowing CTA and entrance motion.

/// Status colours, all shades of the brand palette: a ramp from bright
/// mint (healthy) through deep teal (monitor) to navy (needs attention),
/// so the more serious a finding, the deeper its colour.
abstract class HealthColors {
  static const Color healthy = AppColors.g1;
  static const Color monitor = Color(0xFF267C7D); // g2 toward navy
  static const Color attention = AppColors.navy;
  static const Color muted = Color(0xFFB7C3C5); // border toward grey

  /// Text and icons on light glass, kept above 4.5:1 contrast.
  static const Color healthyInk = Color(0xFF17807D); // deeper g2
  static const Color monitorInk = monitor;
  static const Color attentionInk = AppColors.navy;

  static Color of(AreaHealth health) => switch (health) {
        AreaHealth.healthy => healthy,
        AreaHealth.monitor => monitor,
        AreaHealth.attention => attention,
        AreaHealth.notChecked => muted,
      };

  static Color ink(AreaHealth health) => switch (health) {
        AreaHealth.healthy => healthyInk,
        AreaHealth.monitor => monitorInk,
        AreaHealth.attention => attentionInk,
        AreaHealth.notChecked => AppColors.secondaryText,
      };

  /// Shade used on the 3D model. Lighter than the dots, so a mouth with
  /// several findings still looks calm: white-mint, light teal, slate
  /// teal.
  static Color modelOf(AreaHealth health) => switch (health) {
        AreaHealth.healthy => AppColors.g1,
        AreaHealth.monitor => AppColors.g2,
        AreaHealth.attention => const Color(0xFF215E61), // g2 toward navy
        AreaHealth.notChecked => muted,
      };

  /// How strongly the 3D model is tinted with [modelOf].
  static double tintOf(AreaHealth health) => switch (health) {
        AreaHealth.healthy => 0.18,
        AreaHealth.monitor => 0.5,
        AreaHealth.attention => 0.58,
        AreaHealth.notChecked => 0,
      };

  /// Region and metric scores, on the same three-step scale.
  static AreaHealth forScore(int score) => score >= 80
      ? AreaHealth.healthy
      : score >= 65
          ? AreaHealth.monitor
          : AreaHealth.attention;
}

/// Figures (scores, percentages, counts) in the app font, with tabular
/// digits so counters don't jitter while they run.
TextStyle figureText({
  double size = 12,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.navy,
  double letterSpacing = 0,
  double? height,
}) =>
    GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Status pill: pale tint, rim and ink.
class HealthChip extends StatelessWidget {
  const HealthChip({super.key, required this.health, this.label});

  final AreaHealth health;

  /// Defaults to the status label.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = HealthColors.of(health);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label ?? health.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: HealthColors.ink(health),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero call to action: the brand gradient with a slow breathing
/// glow. [intensity] (0–1) sets how bright it glows; at full strength a
/// sheen also sweeps across. Disabled (greyed, no glow) without [onTap].
class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.intensity = 0.6,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double intensity;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  static const _radius = BorderRadius.all(Radius.circular(16));

  bool get _enabled => widget.onTap != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GlowButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_enabled && !ScanMotion.reduced(context)) {
      if (!_cycle.isAnimating) _cycle.repeat();
    } else {
      _cycle
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final intensity = widget.intensity.clamp(0.0, 1.0);
    final duration = ScanMotion.of(context, ScanMotion.slow);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _cycle,
        builder: (context, child) {
          final t = _cycle.value;
          final breath = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
          final glow = enabled ? intensity * (0.55 + 0.45 * breath) : 0.0;
          return AnimatedContainer(
            duration: duration,
            curve: ScanMotion.curve,
            decoration: BoxDecoration(
              borderRadius: _radius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.g1.withValues(alpha: 0.1 + 0.4 * glow),
                  blurRadius: 8 + 22 * glow,
                  spreadRadius: -1 + 3 * glow,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                child!,
                // Sheen sweeping across, in the first part of each cycle.
                if (enabled && intensity > 0.9 && t < 0.42)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: _radius,
                        child: FractionalTranslation(
                          translation: Offset(-1.2 + 2.4 * (t / 0.42), 0),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1, -0.4),
                                end: Alignment(1, 0.4),
                                colors: [
                                  Color(0x00FFFFFF),
                                  Color(0x59FFFFFF),
                                  Color(0x00FFFFFF),
                                ],
                                stops: [0.3, 0.5, 0.7],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: _radius,
            child: AnimatedContainer(
              duration: duration,
              curve: ScanMotion.curve,
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: _radius,
                gradient: enabled
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5DE6D6), AppColors.g2],
                      )
                    : null,
                color: enabled ? null : AppColors.navy.withValues(alpha: 0.07),
                border: Border.all(
                  color: enabled
                      ? AppColors.white.withValues(alpha: 0.45)
                      : AppColors.navy.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: enabled
                            ? AppColors.white
                            : AppColors.secondaryText.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  if (widget.icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      widget.icon,
                      size: 20,
                      color: enabled
                          ? AppColors.white
                          : AppColors.secondaryText.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts its child in once, after [delay]. The delay runs on
/// the same ticker, so content built off screen (e.g. under the scan
/// route) still staggers in once it shows.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  static const _length = Duration(milliseconds: 560);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + _length,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMilliseconds / (widget.delay + _length).inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (ScanMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// A checkmark that draws itself in when [visible] turns true.
class DrawnCheck extends StatefulWidget {
  const DrawnCheck({
    super.key,
    required this.visible,
    this.size = 14,
    this.color = AppColors.white,
    this.strokeWidth = 2,
  });

  final bool visible;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  State<DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<DrawnCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: widget.visible ? 1 : 0,
  );

  @override
  void didUpdateWidget(DrawnCheck old) {
    super.didUpdateWidget(old);
    if (widget.visible == old.visible) return;
    if (!widget.visible) {
      _draw.value = 0;
    } else if (ScanMotion.reduced(context)) {
      _draw.value = 1;
    } else {
      _draw.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _draw,
        builder: (context, _) => CustomPaint(
          painter: _CheckPainter(
            Curves.easeOutCubic.transform(_draw.value),
            widget.color,
            widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.progress, this.color, this.strokeWidth);

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.18, h * 0.54)
      ..lineTo(w * 0.42, h * 0.76)
      ..lineTo(w * 0.84, h * 0.28);
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, PathMetric m) => s + m.length);
    var remaining = total * progress;
    final drawn = Path();
    for (final m in metrics) {
      if (remaining <= 0) break;
      drawn.addPath(m.extractPath(0, math.min(remaining, m.length)), Offset.zero);
      remaining -= m.length;
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// Section heading on the light pages, with an optional trailing widget.
class SimSectionTitle extends StatelessWidget {
  const SimSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Small caps label above values ("ORAL HEALTH SCORE").
TextStyle capsLabel({Color color = AppColors.secondaryText}) =>
    GoogleFonts.outfit(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.3,
      color: color,
    );

/// Confidence as a thin bar that fills in, with the percentage.
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({super.key, required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Semantics(
      label: '$percent percent confidence',
      excludeSemantics: true,
      child: Row(
        children: [
          Text('CONFIDENCE', style: capsLabel()),
          const SizedBox(width: 10),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration:
                  ScanMotion.of(context, const Duration(milliseconds: 900)),
              curve: ScanMotion.curve,
              builder: (context, v, _) => Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: AppColors.navy.withValues(alpha: 0.07),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(colors: [
                        color.withValues(alpha: 0.55),
                        color,
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$percent%', style: figureText(size: 12.5)),
        ],
      ),
    );
  }
}
