/// The guided views the scan workflow captures, in order, plus the five
/// regions older screenings used.
///
/// History records store these ids. The backend and ml/inference list the
/// same ones. The app has no tooth-numbering system, so views are described
/// by arch, side and tooth type only.
library;

import 'dart:math' as math;

import '../../dental_explorer/data/tooth_catalog.dart';

enum DentalArch { upper, lower }

/// The user's own left/right. Visuals are drawn mirror-style (the user's
/// left on the left of the screen) and labelled, so no chart convention
/// needs to be known.
enum DentalSide { left, right }

/// Tooth types from the midline outward, one quadrant.
enum ToothKind {
  centralIncisor,
  lateralIncisor,
  canine,
  firstPremolar,
  secondPremolar,
  firstMolar,
  secondMolar;

  bool get isPosterior => index >= ToothKind.firstPremolar.index;
}

/// Which arches a region's visual shows.
enum ArchView {
  upper,
  lower,
  both;

  bool shows(ToothArch arch) => switch (this) {
        ArchView.upper => arch == ToothArch.upper,
        ArchView.lower => arch == ToothArch.lower,
        ArchView.both => true,
      };
}

class ScanRegion {
  const ScanRegion({
    required this.id,
    required this.label,
    required this.description,
    required this.instruction,
    required this.view,
    required this.arches,
    required this.sides,
    required this.kinds,
    this.shortLabel,
    this.tips = const [],
    this.checked = true,
    this.yaw = 0,
    this.pitch = 0.06,
    this.zoom = 1,
    this.renderAsset,
  });

  final String id;
  final String label;

  /// Compact name for tiles and chips. Falls back to [label].
  final String? shortLabel;
  final String description;

  /// One-line positioning instruction shown before capture.
  final String instruction;

  /// Further positioning steps, shown after [instruction].
  final List<String> tips;

  /// False when no model can read this view yet: its photo is saved, and
  /// the app must not imply it was checked for problems.
  final bool checked;

  final ArchView view;

  /// Teeth highlighted in this region's visual.
  final Set<DentalArch> arches;
  final Set<DentalSide> sides;
  final Set<ToothKind> kinds;

  /// The 3D guide's camera (radians): what the phone should see.
  final double yaw;
  final double pitch;

  /// Below 1 moves the guide camera closer than the fitted framing.
  final double zoom;

  /// Optional rendered image that replaces the built-in illustration.
  ///
  /// The built-in visual is a vector drawing with 3D-style lighting, not a
  /// 3D model. To use a real render, add a transparent PNG (1200×840, 10:7)
  /// to `assets/images/` and set this, e.g.
  /// `renderAsset: 'assets/images/scan_region_upper_left.png'`.
  /// A missing file falls back to the illustration.
  final String? renderAsset;

  String get short => shortLabel ?? label;

  bool highlights(DentalArch arch, DentalSide side, ToothKind kind) =>
      arches.contains(arch) && sides.contains(side) && kinds.contains(kind);

  /// Whether this view is the one meant to show [tooth]. Third molars
  /// count with the second molars next to them.
  bool covers(ToothInfo tooth) => highlights(
        tooth.arch == ToothArch.upper ? DentalArch.upper : DentalArch.lower,
        tooth.side == ToothSide.left ? DentalSide.left : DentalSide.right,
        ToothKind.values[math.min(tooth.position, ToothKind.values.length) - 1],
      );

  /// This view's optional second photo: a closer shot of the same teeth.
  ScanRegion get secondPhoto => ScanRegion(
        id: secondPhotoId(id),
        label: '$label, photo 2',
        shortLabel: shortLabel,
        description: description,
        instruction: 'Move closer to the part you most want a clear look at',
        tips: tips,
        view: view,
        arches: arches,
        sides: sides,
        kinds: kinds,
        checked: checked,
        yaw: yaw,
        pitch: pitch,
        zoom: zoom * 0.8,
        renderAsset: renderAsset,
      );
}

const String _secondPhotoSuffix = '-2';

String secondPhotoId(String viewId) => '$viewId$_secondPhotoSuffix';

bool isSecondPhoto(String id) => id.endsWith(_secondPhotoSuffix);

/// The view a photo belongs to: its second photo counts as the same view.
String baseRegionId(String id) => isSecondPhoto(id)
    ? id.substring(0, id.length - _secondPhotoSuffix.length)
    : id;

const Set<ToothKind> _allTeeth = {...ToothKind.values};
const Set<DentalSide> _bothSides = {DentalSide.left, DentalSide.right};
const Set<DentalArch> _bothArches = {DentalArch.upper, DentalArch.lower};
const Set<ToothKind> _frontTeeth = {
  ToothKind.centralIncisor,
  ToothKind.lateralIncisor,
  ToothKind.canine,
};
const Set<ToothKind> _sideTeeth = {
  ToothKind.canine,
  ToothKind.firstPremolar,
  ToothKind.secondPremolar,
  ToothKind.firstMolar,
  ToothKind.secondMolar,
};
const Set<ToothKind> _molars = {ToothKind.firstMolar, ToothKind.secondMolar};

/// The guided views, in capture order. Each photo has one clear job, and
/// the back teeth get their own close-up on each side.
const List<ScanRegion> scanRegions = [
  ScanRegion(
    id: 'front',
    shortLabel: 'Front',
    pitch: 0.06,
    zoom: 1.2,
    label: 'Front Teeth',
    description: 'The front of your upper and lower teeth',
    instruction: 'Smile with your teeth together, device straight on',
    tips: [
      'Hold the device level with your front teeth, close but not touching',
      'The built-in lights do the work. Tilt it slightly if you see glare',
    ],
    view: ArchView.both,
    arches: _bothArches,
    sides: _bothSides,
    kinds: _frontTeeth,
  ),
  ScanRegion(
    id: 'upper-occlusal',
    shortLabel: 'Upper Biting',
    pitch: -math.pi / 2,
    label: 'Upper Biting Surface',
    description: 'The chewing surfaces of your upper teeth',
    instruction: 'Open wide and point the device up at your upper teeth',
    tips: [
      'Keep the head just under your teeth, without touching them',
      'Fit every upper tooth, front to back, in the frame',
    ],
    view: ArchView.upper,
    arches: {DentalArch.upper},
    sides: _bothSides,
    kinds: _allTeeth,
  ),
  ScanRegion(
    id: 'lower-occlusal',
    shortLabel: 'Lower Biting',
    pitch: math.pi / 2,
    label: 'Lower Biting Surface',
    description: 'The chewing surfaces of your lower teeth',
    instruction: 'Open wide and point the device down at your lower teeth',
    tips: [
      'Rest your tongue behind your lower front teeth',
      'Fit every lower tooth, front to back, in the frame',
    ],
    view: ArchView.lower,
    arches: {DentalArch.lower},
    sides: _bothSides,
    kinds: _allTeeth,
  ),
  ScanRegion(
    id: 'left',
    shortLabel: 'Left Side',
    yaw: -math.pi / 2 + 0.22,
    pitch: 0.06,
    label: 'Left Side',
    description: 'The outside of your left teeth',
    instruction: 'Pull your left cheek back with a clean finger and bite together',
    tips: [
      'Hold the device beside your teeth, level with them',
      'Get the last tooth you can see into the frame',
    ],
    view: ArchView.both,
    arches: _bothArches,
    sides: {DentalSide.left},
    kinds: _sideTeeth,
  ),
  ScanRegion(
    id: 'right',
    shortLabel: 'Right Side',
    yaw: math.pi / 2 - 0.22,
    pitch: 0.06,
    label: 'Right Side',
    description: 'The outside of your right teeth',
    instruction: 'Pull your right cheek back with a clean finger and bite together',
    tips: [
      'Hold the device beside your teeth, level with them',
      'Get the last tooth you can see into the frame',
    ],
    view: ArchView.both,
    arches: _bothArches,
    sides: {DentalSide.right},
    kinds: _sideTeeth,
  ),
  ScanRegion(
    id: 'upper-lingual',
    shortLabel: 'Upper Inner',
    yaw: math.pi,
    pitch: -0.62,
    label: 'Back of Upper Teeth',
    description: 'The roof-of-mouth side of your upper teeth',
    instruction: 'Open wide and angle the device up toward the roof of your mouth',
    tips: [
      'Hold it just below your lower front teeth',
      'The slim head reaches this angle, so no mirror is needed',
    ],
    view: ArchView.upper,
    arches: {DentalArch.upper},
    sides: _bothSides,
    kinds: _allTeeth,
    checked: false,
  ),
  ScanRegion(
    id: 'lower-lingual',
    shortLabel: 'Lower Inner',
    yaw: math.pi,
    pitch: 0.62,
    label: 'Back of Lower Teeth',
    description: 'The tongue side of your lower teeth',
    instruction: 'Open, lift your tongue and angle the device down',
    tips: [
      'Hold it just above your upper front teeth',
      'The slim head reaches this angle, so no mirror is needed',
    ],
    view: ArchView.lower,
    arches: {DentalArch.lower},
    sides: _bothSides,
    kinds: _allTeeth,
    checked: false,
  ),
  ScanRegion(
    id: 'back-left',
    shortLabel: 'Left Molars',
    yaw: -0.82,
    pitch: 0.3,
    zoom: 1.4,
    label: 'Back Molars, Left',
    description: 'Your rearmost teeth on the left',
    instruction: 'Open wide and move the device to the left corner of your mouth',
    tips: [
      'Fill the frame with your last two or three teeth',
      'Include the wisdom tooth area if you have one',
    ],
    view: ArchView.both,
    arches: _bothArches,
    sides: {DentalSide.left},
    kinds: _molars,
  ),
  ScanRegion(
    id: 'back-right',
    shortLabel: 'Right Molars',
    yaw: 0.82,
    pitch: 0.3,
    zoom: 1.4,
    label: 'Back Molars, Right',
    description: 'Your rearmost teeth on the right',
    instruction: 'Open wide and move the device to the right corner of your mouth',
    tips: [
      'Fill the frame with your last two or three teeth',
      'Include the wisdom tooth area if you have one',
    ],
    view: ArchView.both,
    arches: _bothArches,
    sides: {DentalSide.right},
    kinds: _molars,
  ),
];

/// The original regions. New scans don't use them; old screenings keep them.
const List<ScanRegion> legacyScanRegions = [
  ScanRegion(
    id: 'ul',
    label: 'Upper Left',
    description: 'Left side of the upper dental arch',
    instruction: 'Position the device toward the upper-left teeth',
    view: ArchView.upper,
    arches: {DentalArch.upper},
    sides: {DentalSide.left},
    kinds: _allTeeth,
    // renderAsset: 'assets/images/scan_region_upper_left.png',
  ),
  ScanRegion(
    id: 'ur',
    label: 'Upper Right',
    description: 'Right side of the upper dental arch',
    instruction: 'Position the device toward the upper-right teeth',
    view: ArchView.upper,
    arches: {DentalArch.upper},
    sides: {DentalSide.right},
    kinds: _allTeeth,
    // renderAsset: 'assets/images/scan_region_upper_right.png',
  ),
  ScanRegion(
    id: 'll',
    label: 'Lower Left',
    description: 'Left side of the lower dental arch',
    instruction: 'Tilt slightly downward toward the lower-left teeth',
    view: ArchView.lower,
    arches: {DentalArch.lower},
    sides: {DentalSide.left},
    kinds: _allTeeth,
    // renderAsset: 'assets/images/scan_region_lower_left.png',
  ),
  ScanRegion(
    id: 'lr',
    label: 'Lower Right',
    description: 'Right side of the lower dental arch',
    instruction: 'Tilt slightly downward toward the lower-right teeth',
    view: ArchView.lower,
    arches: {DentalArch.lower},
    sides: {DentalSide.right},
    kinds: _allTeeth,
    // renderAsset: 'assets/images/scan_region_lower_right.png',
  ),
  ScanRegion(
    id: 'po',
    label: 'Posterior',
    description: 'Back teeth on both arches',
    instruction: 'Move toward the back teeth and keep the device steady',
    view: ArchView.both,
    arches: {DentalArch.upper, DentalArch.lower},
    sides: {DentalSide.left, DentalSide.right},
    kinds: {
      ToothKind.firstPremolar,
      ToothKind.secondPremolar,
      ToothKind.firstMolar,
      ToothKind.secondMolar,
    },
    // renderAsset: 'assets/images/scan_region_posterior.png',
  ),
];

/// Any view, second photo or old region, or null for an unknown id.
ScanRegion? findScanRegion(String id) {
  final base = baseRegionId(id);
  for (final r in [...scanRegions, ...legacyScanRegions]) {
    if (r.id == base) return base == id ? r : r.secondPhoto;
  }
  return null;
}

ScanRegion scanRegionById(String id) => findScanRegion(id)!;

/// Where this photo's view sits in the guided order.
int scanRegionIndex(String id) {
  final base = baseRegionId(id);
  return scanRegions.indexWhere((r) => r.id == base);
}

/// The rows to show for a saved screening: the scheme it was captured with,
/// then any second photos right after their view.
List<ScanRegion> regionsForSession(List<String> capturedIds) {
  final legacy = legacyScanRegions.any((r) => capturedIds.contains(r.id));
  return [
    for (final r in legacy ? legacyScanRegions : scanRegions) ...[
      r,
      if (capturedIds.contains(secondPhotoId(r.id))) r.secondPhoto,
    ],
  ];
}
