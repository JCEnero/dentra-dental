import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/onboarding_content.dart';

/// Height of the overlaid header (logo and Skip), below the status bar.
const double kOnboardingHeaderExtent = 64;

/// Widest the copy and controls grow on tablets and foldables.
const double kOnboardingMaxContentWidth = 520;

/// Height of the main button, and size of the round Back button.
const double kOnboardingButtonHeight = 58;

/// Deep teal from the logo's wordmark, for teal words on light glass. It
/// keeps 4.5:1 contrast where the brand teal would not.
const Color kOnboardingInk = Color(0xFF1D7F8E);

/// Vertical layout shared by the stage, every slide's copy and the
/// controls, so the picture and the words never overlap whatever the screen
/// height, safe areas or text size.
@immutable
class OnboardingGeometry {
  const OnboardingGeometry._({
    required this.stageTop,
    required this.stageBottom,
    required this.copyTop,
    required this.copyBottom,
    required this.controlsBottom,
  });

  factory OnboardingGeometry.of(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final textFactor = (media.textScaler.scale(16) / 16).clamp(1.0, 1.6);

    final controlsBottom = media.padding.bottom > 0
        ? media.padding.bottom + AppSpacing.sm + 2
        : AppSpacing.lg - 2;
    // Dots, the gap under them, then the buttons.
    const controlsHeight = 7 + 22 + kOnboardingButtonHeight;
    final copyBottom = height - controlsBottom - controlsHeight - 20;

    // A two-line headline, a two- or three-line sentence and a note at the
    // default text size; grows with larger system text.
    final copyHeight = 144 * textFactor;
    final stageTop = media.padding.top + kOnboardingHeaderExtent;
    // The picture keeps at least 30% of the screen; past that, the copy
    // scrolls instead.
    final copyTop = math.min(
      math.max(copyBottom - copyHeight, stageTop + height * 0.3),
      copyBottom,
    );

    return OnboardingGeometry._(
      stageTop: stageTop,
      stageBottom: math.max(stageTop, copyTop - 6),
      copyTop: copyTop,
      copyBottom: copyBottom,
      controlsBottom: controlsBottom,
    );
  }

  /// The band the stage's scene is laid out in.
  final double stageTop;
  final double stageBottom;

  /// The band each slide's copy sits in.
  final double copyTop;
  final double copyBottom;

  /// Space below the controls, safe area included.
  final double controlsBottom;

  @override
  bool operator ==(Object other) =>
      other is OnboardingGeometry &&
      other.stageTop == stageTop &&
      other.copyTop == copyTop &&
      other.copyBottom == copyBottom;

  @override
  int get hashCode => Object.hash(stageTop, copyTop, copyBottom);
}

/// One slide's words: headline, sentence and optional note, centred under
/// the stage. They slide with the page and trail it slightly, fading as
/// they leave, while the stage above moves on its own.
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({
    super.key,
    required this.content,
    required this.index,
    required this.pageController,
    required this.geometry,
  });

  final OnboardingSlideContent content;
  final int index;
  final PageController pageController;
  final OnboardingGeometry geometry;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final copy = _SlideCopy(content: content);

    return Stack(
      children: [
        Positioned(
          top: geometry.copyTop,
          height: math.max(0.0, geometry.copyBottom - geometry.copyTop),
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kOnboardingMaxContentWidth,
              ),
              child: reduceMotion
                  ? copy
                  : _Parallax(
                      controller: pageController,
                      index: index,
                      child: copy,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Scrolls only when it cannot fit (very short screens or the largest text
/// sizes), with its last line fading so it reads as scrollable.
class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.content});

  final OnboardingSlideContent content;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // Steps down on narrow or short screens, leaving room for the stage.
    final headlineSize = math
        .min(screen.width * 0.08, screen.height * 0.04)
        .clamp(25.0, 32.0)
        .toDouble();

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 1 - 14 / bounds.height.clamp(14.0, double.infinity), 1.0],
      ).createShader(bounds),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg + 4),
        child: Column(
          children: [
            Semantics(
              header: true,
              child: Text.rich(
                _headlineSpan(),
                textAlign: TextAlign.center,
                // Display type is already large; cap extra scaling so the
                // composition holds while staying readable.
                textScaler: MediaQuery.textScalerOf(context).clamp(
                  maxScaleFactor: 1.3,
                ),
                style: GoogleFonts.outfit(
                  fontSize: headlineSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -headlineSize * 0.025,
                  height: 1.12,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
            if (content.note case final note?) ...[
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(children: [
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  TextSpan(text: note),
                ]),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: AppColors.secondaryText,
                ),
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
        style: const TextStyle(color: kOnboardingInk),
      ),
      TextSpan(text: text.substring(at + accent.length)),
    ]);
  }
}

/// Holds the words back a little against the swipe and fades them as they
/// leave, so they trail the page instead of moving as one block with it.
class _Parallax extends StatelessWidget {
  const _Parallax({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
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
        if (offset == 0) return child!;
        final width = MediaQuery.sizeOf(context).width;
        return Opacity(
          opacity: (1 - offset.abs() * 1.4).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(offset * width * 0.3, 0),
            child: child,
          ),
        );
      },
    );
  }
}
