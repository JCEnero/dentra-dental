/// Static copy for a single welcome slide.
///
/// Kept free of widgets so content can be edited (or localised) without
/// touching layout or navigation code. The pictures live on the shared
/// stage (`WelcomeStage`), which follows the slides as they swipe.
class OnboardingSlideContent {
  const OnboardingSlideContent({
    required this.headline,
    required this.description,
    required this.visualDescription,
    this.headlineAccent,
    this.note,
  });

  /// Slide title. Wraps naturally to the available width.
  final String headline;

  /// Part of [headline] drawn in the brand teal, e.g. the product name.
  final String? headlineAccent;

  /// One supporting sentence.
  final String description;

  /// Optional small print under the description.
  final String? note;

  /// Screen-reader description of what the stage shows on this slide.
  final String visualDescription;
}

/// The welcome slides, in order: what DENTRA is, how it scans, what it
/// finds, and how it keeps track.
const List<OnboardingSlideContent> onboardingSlides = [
  OnboardingSlideContent(
    headline: 'Meet DENTRA',
    headlineAccent: 'DENTRA',
    description:
        'A wireless dental camera that works hand in hand with your phone.',
    visualDescription:
        'The DENTRA camera, a slim white handheld with a round lens head, '
        'turning slowly in front of a glass orb.',
  ),
  OnboardingSlideContent(
    headline: 'Scan Every Side',
    description: "Dentra's slim head reaches every tooth, and each photo "
        'goes straight to your phone.',
    visualDescription:
        'A 3D model of white glass teeth in teal gums. Each area lights up in '
        'turn and its photo flies into a grid on a phone.',
  ),
  OnboardingSlideContent(
    headline: 'See What Needs Care',
    description:
        'Dentra checks your photos and marks the areas worth a closer look.',
    visualDescription:
        'A phone showing a map of the mouth. A light sweeps over it and two '
        'areas are marked in teal.',
  ),
  OnboardingSlideContent(
    headline: 'Track Your Smile',
    description: 'Every scan is kept in one place, so you can see how your '
        'teeth change over time.',
    visualDescription:
        'A phone showing a line of past scans rising over time, with the '
        'DENTRA camera standing beside it.',
  ),
];
