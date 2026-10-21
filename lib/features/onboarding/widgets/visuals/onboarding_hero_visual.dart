import 'package:flutter/material.dart';
import '../../data/onboarding_content.dart';
import 'intro_visual.dart';
import 'monitoring_visual.dart';
import 'screening_visual.dart';

/// Side of the square design canvas every visual is drawn on.
const double kVisualCanvas = 320;

/// Hero visual for a slide.
///
/// Each visual is composed on a fixed 320×320 design canvas and scaled
/// uniformly, so proportions and strokes stay consistent on every screen
/// size.
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
    final visual = switch (content.visual) {
      OnboardingVisual.introduction => IntroVisual(animate: animate),
      OnboardingVisual.screening => ScreeningVisual(animate: animate),
      OnboardingVisual.monitoring => MonitoringVisual(animate: animate),
    };

    return Semantics(
      image: true,
      label: content.visualDescription,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox.square(dimension: kVisualCanvas, child: visual),
        ),
      ),
    );
  }
}
