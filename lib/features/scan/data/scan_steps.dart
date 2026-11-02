/// What the 3D scan tells people while they wait, in the order the work
/// really happens. Each line describes something the app actually does (see
/// ml/inference's pipeline.py and rules.py), in everyday words. Edit freely,
/// but keep it true.
library;

class ScanStep {
  const ScanStep(this.title, this.body);

  final String title;
  final String body;
}

/// Saving and sending, once for the whole scan.
const List<ScanStep> sendingSteps = [
  ScanStep(
    'Saving your scan',
    "First we save this scan to your history, so nothing is lost if your "
        "connection drops. You'll find it there any time.",
  ),
  ScanStep(
    'Sending your photos',
    'Your photos are going to your account one at a time. They stay private, '
        "and they're only used for your screening.",
  ),
];

/// What happens to every photo, in order.
const List<ScanStep> readingSteps = [
  ScanStep(
    'Checking the light',
    'We start by looking at how bright each photo is. A dark photo or too much '
        'glare can hide what is really on your teeth.',
  ),
  ScanStep(
    'Finding your teeth',
    'Next we look for the shape of teeth: pale, bumpy shapes beside your pink '
        'gums and lips. A photo without them comes back to you for a retake.',
  ),
  ScanStep(
    'Checking the focus',
    "Then we check how sharp the photo is. A blurry photo could hide a problem, "
        "so we'd rather ask you to take it again than guess.",
  ),
  ScanStep(
    'Looking for signs of tooth decay',
    'Now we go over each photo for marks that can mean tooth decay. The check '
        'learned what these look like from more than 5,000 dental photos.',
  ),
  ScanStep(
    'Checking for braces',
    "We also look for braces, because they can hide parts of your teeth. If we "
        "see them, we'll tell you so you know what this check may have missed.",
  ),
  ScanStep(
    "Setting aside what we're unsure of",
    "Anything we aren't confident about is marked as faint and gets no advice, "
        "so you can see how sure we are. Your age matters here, since children's "
        'teeth need a closer look.',
  ),
];

/// Bringing the photos together, once for the whole scan.
const List<ScanStep> resultSteps = [
  ScanStep(
    'Working out what to do next',
    'We put all your photos together to see which parts of your mouth stand '
        'out. Then we work out how soon a dentist should take a look.',
  ),
  ScanStep(
    'Writing your results',
    'Last, we turn it all into a map of general areas of your mouth and your '
        'own photos with each sign marked. Remember, this is a screening, not a '
        'diagnosis.',
  ),
];

/// Every step, in order.
const List<ScanStep> allScanSteps = [
  ...sendingSteps,
  ...readingSteps,
  ...resultSteps,
];
