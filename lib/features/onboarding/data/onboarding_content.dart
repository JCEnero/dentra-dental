/// Which hero illustration (and backdrop/forms variation) a slide uses.
enum OnboardingVisual { introduction, imagingDevice, monitoring }

/// Static copy and visual configuration for a single onboarding slide.
///
/// Kept free of widgets so content can be edited (or localised) without
/// touching layout or navigation code.
class OnboardingSlideContent {
  const OnboardingSlideContent({
    required this.headline,
    required this.visual,
    required this.visualDescription,
    this.tagline,
    this.imageAsset,
  });

  /// Stacked display headline. Line breaks (`\n`) are deliberate and are
  /// kept on every screen size; the headline scales down rather than
  /// re-wrapping.
  final String headline;

  /// Optional single short supporting line.
  final String? tagline;

  /// Built-in illustration, backdrop tone and white-form variation.
  final OnboardingVisual visual;

  /// Screen-reader description of the hero visual.
  final String visualDescription;

  /// Path to a finished render (PNG/WebP with transparent background,
  /// square, ideally 1080×1080, lit for a turquoise background). When set, it
  /// replaces the built-in illustration; backdrop and white forms remain.
  /// The file must live in a folder declared under `flutter: assets:` in
  /// pubspec.yaml (e.g. `assets/images/`).
  final String? imageAsset;
}

/// The three onboarding slides, in order.
///
/// To swap an illustration for a real render, set `imageAsset`, e.g.
/// `imageAsset: 'assets/images/onboarding_device.png'`.
const List<OnboardingSlideContent> onboardingSlides = [
  OnboardingSlideContent(
    headline: 'MEET YOUR\nSMILE\nCOMPANION.',
    tagline: 'Friendly, AI-assisted dental screening at home.',
    visual: OnboardingVisual.introduction,
    visualDescription:
        'The DENTRA tooth-rabbit mascot waving hello from a pedestal, '
        'with a toothbrush, bubbles and sparkles floating around it.',
  ),
  OnboardingSlideContent(
    headline: 'SEE\nBEYOND\nTHE OBVIOUS.',
    tagline: "Capture hard-to-reach areas with DENTRA's imaging device.",
    visual: OnboardingVisual.imagingDevice,
    visualDescription:
        'A handheld intraoral imaging device scanning the DENTRA mascot, '
        'who looks up at the lens.',
  ),
  OnboardingSlideContent(
    headline: 'YOUR SMILE.\nYOUR JOURNEY.',
    tagline: 'Track changes and know when to see a dentist.',
    visual: OnboardingVisual.monitoring,
    visualDescription:
        'Teeth along a timeline, representing check-ins over time, ending '
        'with the DENTRA mascot cheering beside a check mark.',
  ),
];
