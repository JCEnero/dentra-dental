/// Things on screen the app tour points at. Dock buttons carry their
/// index; the rest live on Home.
enum TourSpot {
  teeth,
  treatment,
  comparison,
  rabi,
  notifications,
  home(0),
  scan(1),
  history(2),
  clinics(3),
  profile(4);

  const TourSpot([this.dockIndex]);

  /// Index of the dock button, for spots in the bottom dock.
  final int? dockIndex;

  /// The tab this spot is found on.
  int get tab => dockIndex ?? 0;
}

/// One stop on the app tour. Steps with a [spot] put the spotlight on it;
/// the welcome and send-off are a centred card.
class AppTourStep {
  const AppTourStep({
    required this.title,
    required this.body,
    this.spot,
    this.chapter,
    this.action = 'Next',
  });

  final String title;
  final String body;
  final TourSpot? spot;

  /// Groups spots under a small label ("Home", "Getting around").
  final String? chapter;

  /// Label of the primary button.
  final String action;
}

/// Welcome, Home's features, the dock (in order), then a send-off.
const List<AppTourStep> appTourSteps = [
  AppTourStep(
    title: 'Hey, nice to meet you',
    body: "I'm your DENTRA guide. Ten quick stops, about a minute, and "
        "you'll know where everything lives.",
    action: 'Start the tour',
  ),
  AppTourStep(
    spot: TourSpot.teeth,
    chapter: 'Home',
    title: 'Your teeth in 3D',
    body: 'Spin a full 3D model of your mouth. Tap any tooth to learn '
        'what it does and see its history.',
  ),
  AppTourStep(
    spot: TourSpot.treatment,
    chapter: 'Home',
    title: 'Treatments, demystified',
    body: 'Step-by-step guides to common procedures, from cleanings to '
        'fillings, so nothing feels like a surprise.',
  ),
  AppTourStep(
    spot: TourSpot.comparison,
    chapter: 'Home',
    title: 'Spot the difference',
    body: 'Put two screenings side by side, or slide between them, to '
        'see what changed over time.',
  ),
  AppTourStep(
    spot: TourSpot.rabi,
    chapter: 'Home',
    title: 'Meet Rabi',
    body: 'Your AI assistant. Ask about your results or your teeth in '
        'plain words. Rabi guides, a dentist diagnoses.',
  ),
  AppTourStep(
    spot: TourSpot.notifications,
    chapter: 'Home',
    title: 'Stay in the loop',
    body: 'Results, reminders and updates land here. '
        'A dot means something new.',
  ),
  AppTourStep(
    spot: TourSpot.home,
    chapter: 'Getting around',
    title: 'Home base',
    body: 'Device status, daily tip and everything you just saw. '
        'Tap here to come back anytime.',
  ),
  AppTourStep(
    spot: TourSpot.scan,
    chapter: 'Getting around',
    title: 'Scan your smile',
    body: 'Use your DENTRA device or phone camera and capture each '
        'region. We guide every shot.',
  ),
  AppTourStep(
    spot: TourSpot.history,
    chapter: 'Getting around',
    title: "Your smile's story",
    body: 'Every screening and record, on a calendar. '
        'Handy for spotting changes.',
  ),
  AppTourStep(
    spot: TourSpot.clinics,
    chapter: 'Getting around',
    title: 'Find a dentist',
    body: 'Nearby clinics on a map, with directions and contact details '
        'for when you need a pro.',
  ),
  AppTourStep(
    spot: TourSpot.profile,
    chapter: 'Getting around',
    title: 'All about you',
    body: 'Your details, dental profile and settings. '
        'Replay this tour from here anytime.',
  ),
  AppTourStep(
    title: "You're all set",
    body: 'Need a hand later? Rabi is one tap away on Home.',
    action: "Let's go",
  ),
];
