import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/onboarding_content.dart';
import 'onboarding_palette.dart';
import 'visuals/onboarding_hero_visual.dart';

/// Height of the overlaid header (logo and Skip), below the status bar.
const double kOnboardingHeaderExtent = 60;

/// Widest the content column grows on tablets and foldables.
const double kOnboardingMaxContentWidth = 560;

/// Diameter of the round controls, and height of the Get Started pill.
const double kOnboardingButtonSize = 56;

/// Vertical layout shared by the static stage, every slide and the
/// controls, so the visual always sits on teal and the copy on the white
/// surface, whatever the screen height, safe areas or text size.
@immutable
class OnboardingGeometry {
  const OnboardingGeometry._({
    required this.surfaceTop,
    required this.crestDepth,
    required this.visualTop,
    required this.visualBottom,
    required this.copyTop,
    required this.controlsExtent,
    required this.controlsBottomPadding,
  });

  factory OnboardingGeometry.of(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final textFactor = (media.textScaler.scale(16) / 16).clamp(1.0, 1.6);

    final controlsBottomPadding = media.padding.bottom > 0
        ? media.padding.bottom + AppSpacing.sm
        : AppSpacing.lg;
    final controlsExtent =
        controlsBottomPadding + kOnboardingButtonSize + AppSpacing.md;

    const crestDepth = 30.0;
    const copyInset = 14.0;
    // Fits eyebrow, a two-line headline, a three-line description and a
    // note at the default text size; grows with larger system text.
    final copyHeight = 216 * textFactor;

    final visualTop = media.padding.top + kOnboardingHeaderExtent;
    final wanted = crestDepth + copyInset + copyHeight + controlsExtent;
    final surfaceHeight = wanted.clamp(height * 0.40, double.infinity);
    // The visual always keeps at least 30% of the screen; past that, the
    // copy scrolls instead.
    final surfaceTop = (height - surfaceHeight)
        .clamp(visualTop + height * 0.30, height)
        .toDouble();

    return OnboardingGeometry._(
      surfaceTop: surfaceTop,
      crestDepth: crestDepth,
      visualTop: visualTop,
      visualBottom: surfaceTop + crestDepth * 0.25,
      // Never below the controls, so the copy band can't invert.
      copyTop: (surfaceTop + crestDepth + copyInset)
          .clamp(0.0, height - controlsExtent)
          .toDouble(),
      controlsExtent: controlsExtent,
      controlsBottomPadding: controlsBottomPadding,
    );
  }

  /// Highest point of the white surface's curved top edge.
  final double surfaceTop;

  /// How far the curved edge dips below [surfaceTop].
  final double crestDepth;

  /// Band of the teal stage the hero visual is centred in.
  final double visualTop;
  final double visualBottom;

  /// Where the copy starts on the white surface. It runs down to the
  /// controls.
  final double copyTop;

  /// Height of the controls row plus the space around it.
  final double controlsExtent;

  /// Space below the controls (safe area included).
  final double controlsBottomPadding;

  double get visualHeight => visualBottom - visualTop;

  @override
  bool operator ==(Object other) =>
      other is OnboardingGeometry &&
      other.surfaceTop == surfaceTop &&
      other.visualTop == visualTop &&
      other.controlsExtent == controlsExtent;

  @override
  int get hashCode => Object.hash(surfaceTop, visualTop, controlsExtent);
}

/// One slide's moving content: the hero visual on the teal stage and the
/// copy on the white surface. The stage itself, header and controls stay
/// still behind and around it (see `OnboardingStage`).
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({
    super.key,
    required this.content,
    required this.index,
    required this.pageController,
    required this.isActive,
    required this.geometry,
  });

  final OnboardingSlideContent content;
  final int index;
  final PageController pageController;
  final bool isActive;
  final OnboardingGeometry geometry;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final side = [
      geometry.visualHeight - AppSpacing.md,
      width - AppSpacing.lg * 2,
      360.0,
    ].reduce((a, b) => a < b ? a : b).clamp(0.0, 360.0);

    Widget withParallax(double factor, Widget child, {bool fade = false}) =>
        reduceMotion
            ? child
            : _Parallax(
                controller: pageController,
                index: index,
                factor: factor,
                fade: fade,
                child: child,
              );

    return Stack(
      children: [
        Positioned(
          top: geometry.visualTop,
          height: geometry.visualHeight,
          left: 0,
          right: 0,
          child: Center(
            child: withParallax(
              0.30,
              fade: true,
              RepaintBoundary(
                child: SizedBox.square(
                  dimension: side,
                  child: OnboardingHeroVisual(
                    content: content,
                    animate: isActive,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: geometry.copyTop,
          bottom: geometry.controlsExtent,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kOnboardingMaxContentWidth,
              ),
              child: withParallax(0.12, _SlideCopy(content: content)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Eyebrow, headline, description and optional note. Scrolls only when it
/// cannot fit (very short screens or the largest text sizes).
class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.content});

  final OnboardingSlideContent content;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // Steps down on narrow or short screens, leaving room for the copy.
    final headlineSize = [screen.width * 0.08, screen.height * 0.042]
        .reduce((a, b) => a < b ? a : b)
        .clamp(26.0, 32.0);

    // If the copy ever overflows, its last line fades out instead of being
    // cut, so it reads as scrollable.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 1 - 16 / bounds.height.clamp(16.0, double.infinity), 1.0],
      ).createShader(bounds),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.eyebrow.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                height: 1.2,
                color: OnboardingPalette.ink,
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              header: true,
              child: Text.rich(
                _headlineSpan(),
                // Display type is already large; cap extra scaling so the
                // composition holds while staying readable.
                textScaler: MediaQuery.textScalerOf(context).clamp(
                  maxScaleFactor: 1.3,
                ),
                style: GoogleFonts.outfit(
                  fontSize: headlineSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -headlineSize * 0.02,
                  height: 1.12,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content.description,
              style: GoogleFonts.outfit(
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
            if (content.note case final note?) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  /// The headline, with [OnboardingSlideContent.headlineAccent] in teal.
  TextSpan _headlineSpan() {
    final text = content.headline;
    final accent = content.headlineAccent;
    final at = accent == null ? -1 : text.indexOf(accent);
    if (accent == null || at < 0) return TextSpan(text: text);
    return TextSpan(children: [
      TextSpan(text: text.substring(0, at)),
      TextSpan(
        text: accent,
        style: const TextStyle(color: OnboardingPalette.ink),
      ),
      TextSpan(text: text.substring(at + accent.length)),
    ]);
  }
}

/// Shifts a layer against the swipe direction by [factor] of the screen
/// width, so the visual and copy trail the page at different depths.
class _Parallax extends StatelessWidget {
  const _Parallax({
    required this.controller,
    required this.index,
    required this.factor,
    required this.child,
    this.fade = false,
  });

  final PageController controller;
  final int index;
  final double factor;
  final bool fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var offset = 0.0;
        if (controller.hasClients && controller.position.haveDimensions) {
          offset = (controller.page ?? index.toDouble()) - index;
        }
        final width = MediaQuery.sizeOf(context).width;
        final shifted = Transform.translate(
          offset: Offset(offset * width * factor, 0),
          child: child,
        );
        if (!fade || offset == 0) return shifted;
        return Opacity(
          opacity: (1 - offset.abs() * 0.9).clamp(0.0, 1.0),
          child: shifted,
        );
      },
    );
  }
}
