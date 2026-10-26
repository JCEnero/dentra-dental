import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/mock_scan_report.dart';
import '../scan_motion.dart';

// Shared look for the scan simulation: health colours, the HUD typeface,
// dark "holo" glass for 3D views, the glowing CTA and entrance motion.

/// Green, amber and red are used for tooth health only.
abstract class HealthColors {
  static const Color healthy = Color(0xFF22C38E);
  static const Color monitor = Color(0xFFF2A93B);
  static const Color attention = Color(0xFFEF5A5F);
  static const Color muted = Color(0xFF8FA3AB);

  /// Text and icons on light glass, kept above 4.5:1 contrast.
  static const Color healthyInk = Color(0xFF12805B);
  static const Color monitorInk = Color(0xFF975A00);
  static const Color attentionInk = AppColors.dangerInk;

  static Color of(ToothHealth health) => switch (health) {
        ToothHealth.healthy => healthy,
        ToothHealth.monitor => monitor,
        ToothHealth.attention => attention,
        ToothHealth.notAssessed => muted,
      };

  static Color ink(ToothHealth health) => switch (health) {
        ToothHealth.healthy => healthyInk,
        ToothHealth.monitor => monitorInk,
        ToothHealth.attention => attentionInk,
        ToothHealth.notAssessed => AppColors.secondaryText,
      };

  /// Region and metric scores, on the same three-step scale.
  static ToothHealth forScore(int score) => score >= 80
      ? ToothHealth.healthy
      : score >= 65
          ? ToothHealth.monitor
          : ToothHealth.attention;
}

/// Night palette for the scan chamber and 3D panels.
abstract class HoloColors {
  static const Color space = Color(0xFF030A12);
  static const Color deep = Color(0xFF061423);
  static const Color panel = Color(0xFF0B2133);
  static const Color cyan = Color(0xFF5CF0FF);
  static const Color text = Color(0xFFE8FBFF);
  static const Color textDim = Color(0xA6CFEFF5);
  static const Color rim = Color(0x524DD8C8);
}

/// Orbitron, for numbers and machine readouts.
TextStyle hudText({
  double size = 12,
  FontWeight weight = FontWeight.w600,
  Color color = AppColors.navy,
  double letterSpacing = 0.8,
  double? height,
}) =>
    GoogleFonts.orbitron(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

/// Dark frosted glass that frames 3D views on the light pages.
class HoloPanel extends StatelessWidget {
  const HoloPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // A soft teal halo instead of a shadow, like light leaking out.
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.g2.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: GlassBlur(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF00C2235), Color(0xF5061423)],
              ),
              border: Border.all(color: HoloColors.rim),
            ),
            child: padding == null
                ? child
                : Padding(padding: padding!, child: child),
          ),
        ),
      ),
    );
  }
}

/// Small dark-glass surface used on top of the 3D scene.
BoxDecoration holoGlass({
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(16)),
  Color? borderColor,
}) =>
    BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF14324A).withValues(alpha: 0.62),
          const Color(0xFF07182A).withValues(alpha: 0.72),
        ],
      ),
      border: Border.all(color: borderColor ?? HoloColors.rim),
    );

/// Health status pill: pale tint, rim and ink, never a solid block.
class HealthChip extends StatelessWidget {
  const HealthChip({super.key, required this.health, this.label, this.dark = false});

  final ToothHealth health;

  /// Defaults to the health label.
  final String? label;

  /// For dark (holo) surfaces.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = HealthColors.of(health);
    final ink = dark ? color : HealthColors.ink(health);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.16 : 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: dark ? 0.45 : 0.32)),
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
                color: ink,
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
