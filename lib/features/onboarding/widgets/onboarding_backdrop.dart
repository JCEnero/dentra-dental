import 'package:flutter/material.dart';
import '../data/onboarding_content.dart';
import 'onboarding_palette.dart';

/// Full-bleed turquoise background for a slide.
///
/// Each slide is a different direction and blend of the Home tab's
/// cyan-mint → turquoise gradient, with a soft mint glow behind the hero
/// visual.
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({super.key, required this.visual});

  final OnboardingVisual visual;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(visual);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: tone.begin,
          end: tone.end,
          colors: tone.colors,
          stops: tone.stops,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: tone.glowCenter,
            radius: 0.9,
            colors: [
              OnboardingPalette.glow.withValues(alpha: 0.40),
              OnboardingPalette.glow.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  static _Tone _toneFor(OnboardingVisual visual) {
    final highlight = OnboardingPalette.highlight;
    const mint = OnboardingPalette.mint;
    const turquoise = OnboardingPalette.turquoise;
    const base = OnboardingPalette.base;
    return switch (visual) {
      // Same direction as the Home hero card: bright top-left to teal.
      OnboardingVisual.introduction => _Tone(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlight, mint, base],
          stops: const [0.0, 0.5, 1.0],
          glowCenter: const Alignment(0.0, 0.15),
        ),
      OnboardingVisual.imagingDevice => const _Tone(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [mint, turquoise, base],
          stops: [0.0, 0.55, 1.0],
          glowCenter: Alignment(0.45, 0.1),
        ),
      OnboardingVisual.monitoring => _Tone(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlight, turquoise, base],
          stops: const [0.0, 0.55, 1.0],
          glowCenter: const Alignment(0.2, 0.2),
        ),
    };
  }
}

class _Tone {
  const _Tone({
    required this.colors,
    required this.stops,
    required this.glowCenter,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  final List<Color> colors;
  final List<double> stops;
  final Alignment glowCenter;
  final Alignment begin;
  final Alignment end;
}
