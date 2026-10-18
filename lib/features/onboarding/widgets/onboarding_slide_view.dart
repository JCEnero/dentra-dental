import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/onboarding_content.dart';
import 'flowing_forms.dart';
import 'onboarding_backdrop.dart';
import 'visuals/onboarding_hero_visual.dart';

/// Vertical space reserved for the overlaid header and controls. The slide
/// keeps its content clear of both.
const double kOnboardingHeaderExtent = 60;
const double kOnboardingControlsExtent = 96;

/// Widest the content column grows on tablets and foldables.
const double kOnboardingMaxContentWidth = 560;

/// One full-bleed slide: teal backdrop, stacked headline, a short tagline,
/// and the hero visual resting on white flowing forms.
///
/// The headline keeps its deliberate line breaks and scales down to fit the
/// width. If everything cannot fit vertically (short screens, large system
/// text), the hero stops shrinking at a minimum size and the slide scrolls.
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({
    super.key,
    required this.content,
    required this.index,
    required this.pageController,
    required this.isActive,
  });

  final OnboardingSlideContent content;
  final int index;
  final PageController pageController;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        OnboardingBackdrop(visual: content.visual),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              top: kOnboardingHeaderExtent,
              bottom: kOnboardingControlsExtent,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kOnboardingMaxContentWidth,
                ),
                child: LayoutBuilder(builder: _buildContent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, BoxConstraints constraints) {
    final minHeroHeight = (constraints.maxHeight * 0.42).clamp(150.0, 320.0);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              _Headline(
                text: content.headline,
                availableHeight: constraints.maxHeight,
              ),
              if (content.tagline case final tagline?) ...[
                const SizedBox(height: AppSpacing.sm + 6),
                Text(
                  tagline,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
              Expanded(
                // The fixed height only reports a minimum intrinsic size;
                // Expanded's tight constraint overrides it at layout.
                child: SizedBox(
                  height: minHeroHeight,
                  child: _HeroStage(
                    content: content,
                    index: index,
                    pageController: pageController,
                    isActive: isActive,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stacked display headline. It never re-wraps: the authored line breaks are
/// kept and the block scales down if a line would be too wide.
class _Headline extends StatelessWidget {
  const _Headline({required this.text, required this.availableHeight});

  final String text;
  final double availableHeight;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Sized so the longest line ("YOUR JOURNEY.") fits a 360pt phone at
    // full size; FittedBox only shrinks it further on narrower screens.
    var size = (width * 0.098).clamp(30.0, 46.0);
    // On short screens give the hero more room.
    if (availableHeight < 520) {
      size *= (availableHeight / 520).clamp(0.78, 1.0);
    }

    return Semantics(
      header: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          softWrap: false,
          // Display type is already large; cap extra scaling so the
          // composition holds while staying readable.
          textScaler: MediaQuery.textScalerOf(context).clamp(
            maxScaleFactor: 1.15,
          ),
          style: GoogleFonts.outfit(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: AppColors.white,
            letterSpacing: -size * 0.03,
            height: 0.98,
          ),
        ),
      ),
    );
  }
}

/// The hero visual centred in the remaining space, with the white flowing
/// forms extending behind it to both screen edges.
class _HeroStage extends StatelessWidget {
  const _HeroStage({
    required this.content,
    required this.index,
    required this.pageController,
    required this.isActive,
  });

  final OnboardingSlideContent content;
  final int index;
  final PageController pageController;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return LayoutBuilder(
      builder: (context, box) {
        final side = box.biggest.shortestSide.clamp(0.0, 400.0);
        // How far the forms must reach past this box to touch the screen edge.
        final bleed = ((screenWidth - box.maxWidth) / 2).clamp(0.0, 1000.0);
        final heroCenter = Offset(box.maxWidth / 2, box.maxHeight / 2);

        final forms = FlowingForms(
          visual: content.visual,
          heroCenter: heroCenter.translate(bleed, 0),
          heroSide: side,
        );
        final hero = RepaintBoundary(
          child: SizedBox.square(
            dimension: side,
            child: OnboardingHeroVisual(content: content, animate: isActive),
          ),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -bleed,
              right: -bleed,
              top: 0,
              bottom: 0,
              child: reduceMotion
                  ? forms
                  : _Parallax(
                      controller: pageController,
                      index: index,
                      factor: 0.10,
                      child: forms,
                    ),
            ),
            Center(
              child: reduceMotion
                  ? hero
                  : _Parallax(
                      controller: pageController,
                      index: index,
                      factor: 0.28,
                      fade: true,
                      child: hero,
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Shifts a layer against the swipe direction by [factor] of the screen
/// width, so the hero and forms trail the page at different depths.
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
          opacity: (1 - offset.abs() * 0.8).clamp(0.0, 1.0),
          child: shifted,
        );
      },
    );
  }
}
