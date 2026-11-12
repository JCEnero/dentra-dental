import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
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

/// Rabi, the app's mascot, saying a short tip. His [mood] follows what is
/// happening on the page: pointing at what to do, thinking while it works,
/// cheering when it's done, worried when it needs another try.
class RabiTip extends StatelessWidget {
  const RabiTip(
    this.text, {
    super.key,
    this.mood = MascotMood.wave,
    this.busy = false,
    this.size = 104,
  });

  final String text;
  final MascotMood mood;

  /// Rings ripple behind him while something is under way.
  final bool busy;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${CamText.rabiSays}: $text',
      excludeSemantics: true,
      child: Row(
        children: [
          // Turned so his free arm is on the bubble's side.
          DentraMascot(mood: mood, size: size, mirrored: true, busy: busy),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: ScanMotion.of(context, ScanMotion.medium),
              transitionBuilder: ScanMotion.fadeRise,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
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

/// A setup step's own picture, when one is set in [CameraConfig.setupArt].
/// Steps without one show nothing here: Rabi leads the page instead.
class SetupArt extends StatelessWidget {
  const SetupArt({super.key, required this.step, this.height = 150});

  /// Index into [CameraConfig.setupArt].
  final int step;
  final double height;

  /// Whether [step] has a picture.
  static bool has(int step) =>
      step < CameraConfig.setupArt.length &&
      CameraConfig.setupArt[step] != null;

  @override
  Widget build(BuildContext context) {
    if (!has(step)) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Image.asset(
          CameraConfig.setupArt[step]!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
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
