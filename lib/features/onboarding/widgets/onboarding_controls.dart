import 'package:flutter/material.dart';

import '../../../shared/widgets/gloss_pill_button.dart';
import '../../../shared/widgets/guide_kit.dart' show GuideBackButton;
import 'onboarding_progress_indicator.dart';
import 'onboarding_slide_view.dart' show kOnboardingButtonHeight;

/// The controls under the copy: page dots, then a round glass Back button
/// (from the second slide on) beside the glossy main button, which reads
/// Next and becomes Get Started on the last slide.
class OnboardingControls extends StatelessWidget {
  const OnboardingControls({
    super.key,
    required this.pageController,
    required this.slideCount,
    required this.currentIndex,
    required this.finalLabel,
    required this.onNext,
    required this.onBack,
    required this.isBusy,
    this.isPrimaryLoading = false,
  });

  final PageController pageController;
  final int slideCount;
  final int currentIndex;

  /// What the main button says on the final slide.
  final String finalLabel;
  final VoidCallback onNext;
  final VoidCallback onBack;

  /// True while onboarding is exiting. Disables every action.
  final bool isBusy;

  /// Shows a spinner in the main button (when it triggered the exit).
  final bool isPrimaryLoading;

  bool get _isLast => currentIndex == slideCount - 1;

  @override
  Widget build(BuildContext context) {
    final showBack = currentIndex > 0;
    final Widget backSlot = showBack
        ? Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GuideBackButton(
              label: 'Previous slide',
              size: kOnboardingButtonHeight,
              onPressed: isBusy ? () {} : onBack,
            ),
          )
        : const SizedBox(height: kOnboardingButtonHeight);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingProgressIndicator(
          controller: pageController,
          count: slideCount,
          current: currentIndex,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            // Grows in from nothing, so the main button eases aside. Under
            // reduced motion it simply appears: AnimatedSize can't run with
            // no duration.
            if (MediaQuery.disableAnimationsOf(context))
              backSlot
            else
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: backSlot,
              ),
            Expanded(
              child: GlossPillButton(
                label: _isLast ? finalLabel : 'Next',
                semanticLabel: _isLast ? finalLabel : 'Next slide',
                height: kOnboardingButtonHeight,
                loading: isPrimaryLoading,
                onPressed: isBusy && !isPrimaryLoading ? null : onNext,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
