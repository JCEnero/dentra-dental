import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/onboarding_content.dart';
import 'device_visual.dart';
import 'intro_visual.dart';
import 'monitoring_visual.dart';
import 'studio_stage.dart';

/// Hero visual for a slide.
///
/// Uses the slide's `imageAsset` when one is configured. Otherwise it renders
/// the built-in illustration, composed on a fixed 320×320 design canvas and
/// scaled uniformly, so proportions, strokes and labels stay consistent on
/// every screen size.
class OnboardingHeroVisual extends StatelessWidget {
  const OnboardingHeroVisual({
    super.key,
    required this.content,
    required this.animate,
  });

  final OnboardingSlideContent content;

  /// Whether ambient motion should run (only the visible slide animates).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final asset = content.imageAsset;
    final illustration = _buildIllustration();

    return Semantics(
      image: true,
      label: content.visualDescription,
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: asset == null
              ? illustration
              : Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  // Fall back to the illustration if the file is missing.
                  errorBuilder: (_, __, ___) => illustration,
                ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    final visual = switch (content.visual) {
      OnboardingVisual.introduction => IntroVisual(animate: animate),
      OnboardingVisual.imagingDevice =>
        DevicePlaceholderVisual(animate: animate),
      OnboardingVisual.monitoring => MonitoringVisual(animate: animate),
    };
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.square(
        dimension: kVisualCanvas,
        // Labels inside the artwork are decorative and already described for
        // screen readers, so they scale with the artwork rather than with
        // the system text size, and use a fixed base style so the composition
        // does not depend on the surrounding theme.
        child: MediaQuery.withNoTextScaling(
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 10,
              height: 1.2,
              color: AppColors.white,
            ),
            child: visual,
          ),
        ),
      ),
    );
  }
}
