import '../../../shared/widgets/dentra_mascot.dart' show MascotMood;

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
/// the welcome and send-off are Rabi and his bubble, centred.
class AppTourStep {
  const AppTourStep({
    required this.title,
    required this.body,
    this.spot,
    this.chapter,
    this.action = 'Next',
    this.mood = MascotMood.point,
  });

  final String title;
  final String body;
  final TourSpot? spot;

  /// Groups spots under a small label ("Home", "Getting around").
  final String? chapter;

  /// Label of the primary button.
  final String action;

  /// How Rabi stands while he shows this stop.
  final MascotMood mood;
}

/// Welcome, Home's features, the dock (in order), then a send-off.
const List<AppTourStep> appTourSteps = [
  AppTourStep(
    title: "Hi, I'm Rabi",
    body: "Let me show you around. In about a minute, I'll point out your "
        '3D teeth, scans, history, nearby clinics and where to find me '
        'when you need help.',
    action: 'Start the tour',
    mood: MascotMood.wave,
  ),
  AppTourStep(
    spot: TourSpot.teeth,
    chapter: 'Home',
    title: 'Your teeth in 3D',
    body: 'Spin the model. Tap a tooth to see what it does.',
  ),
  AppTourStep(
    spot: TourSpot.treatment,
    chapter: 'Home',
    title: 'Treatments, explained',
    body: 'Step-by-step guides to common procedures.',
  ),
  AppTourStep(
    spot: TourSpot.comparison,
    chapter: 'Home',
    title: 'Spot the difference',
    body: 'Compare two screenings to see what changed.',
    mood: MascotMood.think,
  ),
  AppTourStep(
    spot: TourSpot.rabi,
    chapter: 'Home',
    title: 'Ask me anything',
    body: 'About your results or your teeth, in plain words. I guide, a '
        'dentist diagnoses.',
    mood: MascotMood.wave,
  ),
  AppTourStep(
    spot: TourSpot.notifications,
    chapter: 'Home',
    title: 'Stay in the loop',
    body: 'Results and reminders land here. A dot means something new.',
    mood: MascotMood.watch,
  ),
  AppTourStep(
    spot: TourSpot.home,
    chapter: 'Getting around',
    title: 'Home base',
    body: 'Tap here to come back anytime.',
  ),
  AppTourStep(
    spot: TourSpot.scan,
    chapter: 'Getting around',
    title: 'Scan your smile',
    body: 'Capture each area with your DENTRA device. I guide every shot.',
    mood: MascotMood.cheer,
  ),
  AppTourStep(
    spot: TourSpot.history,
    chapter: 'Getting around',
    title: "Your smile's story",
    body: 'Every screening and record, on a calendar.',
    mood: MascotMood.think,
  ),
  AppTourStep(
    spot: TourSpot.clinics,
    chapter: 'Getting around',
    title: 'Find a dentist',
    body: 'Nearby clinics, with directions and contact details.',
  ),
  AppTourStep(
    spot: TourSpot.profile,
    chapter: 'Getting around',
    title: 'All about you',
    body: 'Your details and settings. Replay this tour from here.',
    mood: MascotMood.wave,
  ),
  AppTourStep(
    title: "You're all set",
    body: "Need a hand? I'm one tap away on Home.",
    action: "Let's go",
    mood: MascotMood.cheer,
  ),
];
