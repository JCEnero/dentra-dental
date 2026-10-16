/// Which hero illustration (and backdrop/forms variation) a slide uses.
enum OnboardingVisual { introduction, imagingDevice, aiScreening, monitoring }

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

/// The four onboarding slides, in order.
///
/// To swap an illustration for a real render, set `imageAsset`, e.g.
/// `imageAsset: 'assets/images/onboarding_device.png'`.
const List<OnboardingSlideContent> onboardingSlides = [
  OnboardingSlideContent(
    headline: 'A CLOSER\nLOOK AT\nYOUR SMILE.',
    tagline: 'Your companion for AI-assisted dental screening.',
    visual: OnboardingVisual.introduction,
    visualDescription: 'A molar tooth floating above a flowing white form.',
    // imageAsset: 'assets/images/onboarding_intro.png',
  ),
  OnboardingSlideContent(
    headline: 'SEE\nBEYOND\nTHE OBVIOUS.',
    tagline: "Capture hard-to-reach areas with DENTRA's imaging device.",
    visual: OnboardingVisual.imagingDevice,
    visualDescription:
        'A handheld intraoral imaging device positioned beside a tooth, '
        'framed as it is captured.',
    // imageAsset: 'assets/images/onboarding_device.png',
  ),
  OnboardingSlideContent(
    headline: 'A SMARTER\nWAY TO\nLOOK CLOSER.',
    tagline: 'Highlights potential concerns. Not a diagnosis.',
    visual: OnboardingVisual.aiScreening,
    visualDescription:
        'A tooth being scanned, with fine outlines marking areas to review.',
    // imageAsset: 'assets/images/onboarding_screening.png',
  ),
  OnboardingSlideContent(
    headline: 'YOUR SMILE.\nYOUR\nJOURNEY.',
    tagline: 'Track changes and know when to see a dentist.',
    visual: OnboardingVisual.monitoring,
    visualDescription:
        'Three teeth along a timeline, representing check-ins over time.',
    // imageAsset: 'assets/images/onboarding_monitoring.png',
  ),
];
