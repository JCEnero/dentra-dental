import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../scan/widgets/scan_motion.dart';
import '../../scan/widgets/scan_theme.dart';
import '../camera_strings.dart';
import '../data/camera_config.dart';

// Small pieces shared by the setup guide and the live camera.

TextStyle camTitleStyle() => GoogleFonts.outfit(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: AppColors.navy,
      letterSpacing: -0.4,
      height: 1.2,
    );

TextStyle camBodyStyle() => GoogleFonts.outfit(
      fontSize: 14.5,
      color: AppColors.secondaryText,
      height: 1.5,
    );

/// Wi-Fi signal as four rising bars.
class SignalBars extends StatelessWidget {
  const SignalBars({
    super.key,
    required this.bars,
    this.height = 12,
    this.color = AppColors.primary,
  });

  /// 0–4.
  final int bars;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final width = height / 4;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: width,
                height: height * (i + 1) / 4,
                margin: EdgeInsets.only(left: i == 0 ? 0 : width * 0.45),
                decoration: BoxDecoration(
                  color: i < bars ? color : color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(width / 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Connected (green) or not (coral), the palette's own status colours.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.on, this.size = 9});

  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.successGreen : AppColors.coral;
    return AnimatedContainer(
      duration: ScanMotion.of(context, ScanMotion.medium),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6),
        ],
      ),
    );
  }
}

/// Rabi, the app's bunny, with a short tip in a speech bubble.
class RabiTip extends StatelessWidget {
  const RabiTip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${CamText.rabiSays}: $text',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Image.asset(
            'assets/images/rabi_avatar.png',
            width: 52,
            height: 52,
            cacheWidth: 156,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: ScanMotion.of(context, ScanMotion.medium),
              transitionBuilder: ScanMotion.fadeRise,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.bottomLeft,
                children: [...previous, if (current != null) current],
              ),
              child: Container(
                key: ValueKey(text),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.82),
                  // The corner nearest Rabi is the bubble's tail.
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
                  border:
                      Border.all(color: AppColors.g2.withValues(alpha: 0.16)),
                ),
                child: Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A setup step's picture: the image set in [CameraConfig.setupArt], or a
/// built-in placeholder of the step's icon on a white disc, with rings that
/// pulse while something is under way.
class SetupArt extends StatefulWidget {
  const SetupArt({
    super.key,
    required this.step,
    required this.icon,
    this.badge,
    this.active = false,
    this.height = 150,
  });

  /// Index into [CameraConfig.setupArt].
  final int step;
  final IconData icon;

  /// A smaller second icon, bottom right.
  final IconData? badge;
  final bool active;
  final double height;

  @override
  State<SetupArt> createState() => _SetupArtState();
}

class _SetupArtState extends State<SetupArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SetupArt old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !ScanMotion.reduced(context)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.step < CameraConfig.setupArt.length
        ? CameraConfig.setupArt[widget.step]
        : null;
    final placeholder = _placeholder();
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: asset == null
            ? placeholder
            : Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }

  Widget _placeholder() {
    final size = widget.height;
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => CustomPaint(
            painter: _RingsPainter(widget.active ? _pulse.value : null),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size * 0.56,
                    height: size * 0.56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                      border: Border.all(
                        color: AppColors.g2.withValues(alpha: 0.16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.g2.withValues(alpha: 0.14),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: size * 0.26,
                      color: AppColors.primary,
                    ),
                  ),
                  if (widget.badge != null)
                    Positioned(
                      right: -size * 0.04,
                      bottom: -size * 0.02,
                      child: ScanIconDisc(
                        widget.badge!,
                        size: size * 0.22,
                        iconSize: size * 0.11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter(this.pulse);

  /// 0–1 while pulsing; null for still rings.
  final double? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide * 0.28;
    final fill = Paint()..color = AppColors.lightLavender.withValues(alpha: 0.9);
    canvas.drawCircle(c, base * 1.32, fill);
    for (final r in [1.62, 1.86]) {
      canvas.drawCircle(
        c,
        base * r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.g2.withValues(alpha: 0.12),
      );
    }
    final p = pulse;
    if (p == null) return;
    for (final t in [p, (p + 0.5) % 1]) {
      canvas.drawCircle(
        c,
        base * (1.1 + 0.8 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.g1.withValues(alpha: 0.55 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.pulse != pulse;
}

/// The big round capture button.
class ShutterButton extends StatefulWidget {
  const ShutterButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;

  /// Null disables it.
  final VoidCallback? onPressed;

  /// Shows a spinner and ignores taps.
  final bool busy;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final fast = ScanMotion.of(context, const Duration(milliseconds: 120));
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy ? CamText.takingPhoto : widget.label,
      onTap: enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: fast,
        opacity: enabled || widget.busy ? 1 : 0.45,
        child: AnimatedScale(
          duration: fast,
          scale: _down ? 0.92 : 1,
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: (down) => setState(() => _down = down),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.9),
                  border: Border.all(
                    color: AppColors.g2.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.g2.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(7),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.cardGradient,
                  ),
                  child: widget.busy
                      ? const Padding(
                          padding: EdgeInsets.all(22),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.white,
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A teal icon on a white disc, for controls over the live picture.
class CamRoundButton extends StatelessWidget {
  const CamRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white.withValues(alpha: 0.92),
        foregroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.white.withValues(alpha: 0.6),
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        padding: EdgeInsets.zero,
        side: BorderSide(color: AppColors.g2.withValues(alpha: 0.16)),
      ),
      icon: Icon(icon, size: size * 0.45),
    );
  }
}

/// An icon on a white disc beside a short title and an optional line.
class CamInfoRow extends StatelessWidget {
  const CamInfoRow({
    super.key,
    required this.icon,
    required this.title,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScanIconDisc(icon, size: 38, iconSize: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      height: 1.3,
                    ),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      body!,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small spinner beside a line of text, for work under way.
class CamBusyLine extends StatelessWidget {
  const CamBusyLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A spinner over a short line, centred.
class CamBusyCenter extends StatelessWidget {
  const CamBusyCenter(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

/// How long a setup step takes to slide to the next.
Duration camMotion(BuildContext context) => dentraMotion(context, 320);
