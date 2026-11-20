import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import 'dentra_glass_ui.dart' show dentraMotion;

/// The app's main call to action: a glossy deep-teal pill with its label
/// centred and an arrow in teal on a white disc at the end. A soft band of
/// light glides across it every few seconds, and a press sinks it a little.
///
/// Used by the welcome slides and the auth screens, so the first steps
/// through the app share one button.
///
/// Pass `onPressed: null` to disable it. While [loading] the disc shows a
/// spinner, the label switches to [loadingLabel] and taps are ignored.
class GlossPillButton extends StatefulWidget {
  const GlossPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    this.loading = false,
    this.loadingLabel,
    this.icon = Icons.arrow_forward_rounded,
    this.height = 58,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// What screen readers hear instead of [label], e.g. "Next slide".
  final String? semanticLabel;
  final bool loading;
  final String? loadingLabel;

  /// The glyph on the white disc.
  final IconData icon;
  final double height;

  @override
  State<GlossPillButton> createState() => _GlossPillButtonState();
}

class _GlossPillButtonState extends State<GlossPillButton>
    with SingleTickerProviderStateMixin {
  // Only tick while the sheen is visible. The original 3.6-second loop
  // showed it from 55% to 85%; the rest needs no animation frames.
  static const _firstPause = Duration(milliseconds: 1980);
  static const _betweenPasses = Duration(milliseconds: 2520);
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1080),
  )..addStatusListener(_onSheenStatus);
  Timer? _sheenPause;

  bool _down = false;

  /// A deeper shade of the brand teal (g2) for the far end of the pill.
  static const Color _deepTeal = Color(0xFF218C8A);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSheen();
  }

  @override
  void didUpdateWidget(GlossPillButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSheen();
  }

  void _syncSheen() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled ||
        widget.onPressed == null ||
        widget.loading) {
      _sheenPause?.cancel();
      _sheenPause = null;
      _sheen
        ..stop()
        ..value = 0;
    } else if (!_sheen.isAnimating && _sheenPause == null) {
      _scheduleSheen(_firstPause);
    }
  }

  void _onSheenStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleSheen(_betweenPasses);
    }
  }

  void _scheduleSheen(Duration delay) {
    _sheenPause = Timer(delay, () {
      _sheenPause = null;
      _sheen.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _sheenPause?.cancel();
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: _buildButton(context));

  Widget _buildButton(BuildContext context) {
    final height = widget.height;
    final disc = height - 14;
    final radius = BorderRadius.all(Radius.circular(height / 2));
    final enabled = widget.onPressed != null;
    final busy = widget.loading;
    final shown = busy ? (widget.loadingLabel ?? widget.label) : widget.label;
    final motion = dentraMotion(context, 200);

    return Semantics(
      button: true,
      enabled: enabled && !busy,
      label: busy ? shown : (widget.semanticLabel ?? widget.label),
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: dentraMotion(context, 180),
        // Disabled stays readable but clearly resting. Loading keeps full
        // strength: it is working, not unavailable.
        opacity: enabled || busy ? 1 : 0.5,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: dentraMotion(context, 140),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              // The brand teal, a shade deeper than the cards so white words
              // stay easy to read across the whole pill.
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.cardSolid, AppColors.g2, _deepTeal],
              ),
              // A soft teal glow under it, no hard edge.
              boxShadow: [
                if (enabled || busy)
                  BoxShadow(
                    color: AppColors.g2.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: -10,
                    offset: const Offset(0, 14),
                  ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: busy ? null : widget.onPressed,
                onHighlightChanged: (down) => setState(() => _down = down),
                splashColor: AppColors.white.withValues(alpha: 0.18),
                highlightColor: AppColors.white.withValues(alpha: 0.06),
                child: SizedBox(
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Glass: light along the top, a bright rim all round.
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.white.withValues(alpha: 0.22),
                                AppColors.white.withValues(alpha: 0),
                              ],
                              stops: const [0, 0.5],
                            ),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                      if (enabled && !busy)
                        IgnorePointer(
                          child: CustomPaint(painter: _SheenPainter(_sheen)),
                        ),
                      Row(
                        children: [
                          // Balances the disc, so the label sits centred.
                          SizedBox(width: disc + 14),
                          Expanded(
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: motion,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.35),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                                // Shrinks to fit rather than cut a word.
                                child: FittedBox(
                                  key: ValueKey(shown),
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    shown,
                                    maxLines: 1,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                      color: AppColors.white,
                                      shadows: [
                                        Shadow(
                                          color: AppColors.navy
                                              .withValues(alpha: 0.18),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedBuilder(
                            animation: _sheen,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                (_down ? 3 : 0) +
                                    (busy
                                        ? 0
                                        : 3 * _SheenPainter.pass(_sheen.value)),
                                0,
                              ),
                              child: child,
                            ),
                            child: Container(
                              width: disc,
                              height: disc,
                              margin: const EdgeInsets.only(right: 7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.navy.withValues(alpha: 0.14),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: AnimatedSwitcher(
                                duration: motion,
                                child: busy
                                    ? const Padding(
                                        key: ValueKey('busy'),
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            AppColors.primary,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        widget.icon,
                                        key: ValueKey(widget.icon),
                                        size: 21,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft band of light gliding across the button, slanted like a
/// reflection, in one part of each loop of [loop].
class _SheenPainter extends CustomPainter {
  _SheenPainter(this.loop) : super(repaint: loop);

  final Animation<double> loop;

  /// 0 → 1 → 0 while the sheen passes, else 0.
  static double pass(double v) {
    if (v <= 0 || v >= 1) return 0;
    return math.sin(v * math.pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    if (t <= 0 || t >= 1) return;
    final width = size.height * 1.4;
    final x = -width + (size.width + width * 2) * Curves.easeInOut.transform(t);
    final band = Rect.fromLTWH(x - width / 2, 0, width, size.height);
    canvas
      ..save()
      ..translate(band.center.dx, band.center.dy)
      ..skew(-0.35, 0)
      ..translate(-band.center.dx, -band.center.dy)
      ..drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppColors.white.withValues(alpha: 0),
              AppColors.white.withValues(alpha: 0.34),
              AppColors.white.withValues(alpha: 0),
            ],
          ).createShader(band),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SheenPainter old) => old.loop != loop;
}
