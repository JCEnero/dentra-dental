/// Which hero visual (and stage lighting) a slide uses.
enum OnboardingVisual { introduction, screening, monitoring }

/// Static copy and visual configuration for a single onboarding slide.
///
/// Kept free of widgets so content can be edited (or localised) without
/// touching layout or navigation code.
class OnboardingSlideContent {
  const OnboardingSlideContent({
    required this.eyebrow,
    required this.headline,
    required this.description,
    required this.visual,
    required this.visualDescription,
    this.headlineAccent,
    this.note,
  });

  /// Short label above the headline that names the slide's topic.
  final String eyebrow;

  /// Slide title. Wraps naturally to the available width.
  final String headline;

  /// Part of [headline] drawn in the brand teal, e.g. the product name.
  final String? headlineAccent;

  /// One or two supporting sentences.
  final String description;

  /// Optional small print under the description.
  final String? note;

  /// Built-in abstract visual drawn above the copy.
  final OnboardingVisual visual;

  /// Screen-reader description of the hero visual.
  final String visualDescription;
}

/// The three onboarding slides, in order.
const List<OnboardingSlideContent> onboardingSlides = [
  OnboardingSlideContent(
    eyebrow: 'Welcome',
    headline: 'Meet DENTRA',
    headlineAccent: 'DENTRA',
    description: 'Your companion for smarter oral health monitoring.',
    visual: OnboardingVisual.introduction,
    visualDescription:
        'A tooth outline inside a frosted glass circle, ringed by fine '
        'orbits.',
  ),
  OnboardingSlideContent(
    eyebrow: 'Smart screening',
    headline: 'See Your Smile Differently',
    description: 'Explore smart dental screening designed to help you '
        'monitor your oral health.',
    note: 'Screening support only, not a medical diagnosis.',
    visual: OnboardingVisual.screening,
    visualDescription:
        'A tooth inside a scanning frame, with a light line sweeping across '
        'it and two areas highlighted.',
  ),
  OnboardingSlideContent(
    eyebrow: 'Screening history',
    headline: 'Your Smile, Your Journey',
    description: 'Keep track of your screening history and stay informed '
        'about your oral health over time.',
    visual: OnboardingVisual.monitoring,
    visualDescription:
        'A rising timeline of past check-ins, ending in a check mark.',
  ),
];
