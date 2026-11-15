/// What the 3D scan tells people while they wait, in the order the work
/// really happens. Each step describes something the service actually does
/// (see ml/inference's quality.py, teeth.py, tiling.py, tooth_check.py,
/// pipeline.py and rules.py): a plain title, a sentence or two on what and
/// why, and one technical line naming the method. Edit freely, but keep every
/// figure true to that code.
library;

class ScanStep {
  const ScanStep(this.title, this.body, this.detail);

  final String title;
  final String body;

  /// The method behind the step, in technical words, for anyone curious.
  final String detail;
}

/// Saving and sending, once for the whole scan.
const List<ScanStep> sendingSteps = [
  ScanStep(
    'Saving your scan',
    'Your scan is written to your history before anything else. If the '
        'connection drops, nothing is lost.',
    'Session record created first · photos follow',
  ),
  ScanStep(
    'Uploading your photos',
    'Each photo goes to your private account, one at a time. They are only '
        'used for your screening.',
    'Sequential upload · private to your account',
  ),
];

/// What happens to every photo, in order.
const List<ScanStep> readingSteps = [
  ScanStep(
    'Measuring light and glare',
    'Each photo is checked for exposure first. Too dark, or too much glare '
        'from saliva, can hide what is on a tooth.',
    'Mean brightness 35–225 of 255 · under 25% clipped highlights',
  ),
  ScanStep(
    'Measuring sharpness',
    'Next the photo is tested for focus. A blurry photo could hide a '
        'problem, so it is sent back for a retake instead of guessed at.',
    'Laplacian variance focus score at 512 px',
  ),
  ScanStep(
    'Confirming teeth are in view',
    'A trained classifier checks the photo really shows teeth. It looks at '
        'the whole frame and at zoomed-in parts of it.',
    'MobileNetV3 teeth classifier · 6 views per photo',
  ),
  ScanStep(
    'Checking for braces',
    'Braces can cover parts of a tooth. If they are found, your results say '
        'what the check may have missed.',
    'MobileNetV3 braces classifier',
  ),
  ScanStep(
    'Scanning for signs of decay',
    'A detection model trained on thousands of labelled dental photos looks '
        'for marks of tooth decay. It reads the full photo and four zoomed '
        'tiles, so small back teeth are not missed.',
    'RF-DETR transformer detector · 5 passes · overlapping boxes merged',
  ),
  ScanStep(
    'Verifying each mark is on a tooth',
    'Every mark is cropped and checked by a second model trained to tell '
        'enamel from soft tissue. Marks on the tongue, gums or palate are '
        'dropped.',
    'Tooth-vs-tissue classifier on each mark plus a 25% margin',
  ),
  ScanStep(
    'Weighing confidence',
    'Each score is calibrated against labelled photos. Marks below the line '
        'are kept as faint and get no advice. The line is lower for children, '
        'whose teeth need a closer look.',
    'Platt-calibrated scores · counted from 60%, or 45% for children',
  ),
];

/// Bringing the photos together, once for the whole scan.
const List<ScanStep> resultSteps = [
  ScanStep(
    'Mapping marks to your mouth',
    'Marks from every photo are placed on six general areas of your mouth. '
        'Fixed, reviewable rules then set how soon a dentist should look.',
    'Rule-based triage · 6 mouth areas · no tooth numbering',
  ),
  ScanStep(
    'Building your report',
    'Your results are drawn on your own photos, with what to do next. This '
        'is a screening, not a diagnosis.',
    'Marks plotted on your photos · screening only',
  ),
];

/// Every step, in order.
const List<ScanStep> allScanSteps = [
  ...sendingSteps,
  ...readingSteps,
  ...resultSteps,
];
