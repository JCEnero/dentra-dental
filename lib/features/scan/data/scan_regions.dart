/// Dental regions the scan workflow captures, in guided order.
///
/// Ids and labels are unchanged from the original `MockData.scanRegions`;
/// history records store these ids. The app has no tooth-numbering system,
/// so regions are described by arch, side and tooth type only.
library;

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
enum ArchView { upper, lower, both }

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
    this.renderAsset,
  });

  final String id;
  final String label;
  final String description;

  /// One-line positioning instruction shown before capture.
  final String instruction;

  final ArchView view;

  /// Teeth highlighted in this region's visual.
  final Set<DentalArch> arches;
  final Set<DentalSide> sides;
  final Set<ToothKind> kinds;

  /// Optional rendered image that replaces the built-in illustration.
  ///
  /// The built-in visual is a vector drawing with 3D-style lighting, not a
  /// 3D model. To use a real render, add a transparent PNG (1200×840, 10:7)
  /// to `assets/images/` and set this, e.g.
  /// `renderAsset: 'assets/images/scan_region_upper_left.png'`.
  /// A missing file falls back to the illustration.
  final String? renderAsset;

  bool highlights(DentalArch arch, DentalSide side, ToothKind kind) =>
      arches.contains(arch) && sides.contains(side) && kinds.contains(kind);
}

const Set<ToothKind> _allTeeth = {...ToothKind.values};

const List<ScanRegion> scanRegions = [
  ScanRegion(
    id: 'ul',
    label: 'Upper Left',
    description: 'Left side of the upper dental arch',
    instruction: 'Position the camera toward the upper-left teeth',
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
    instruction: 'Position the camera toward the upper-right teeth',
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

ScanRegion scanRegionById(String id) =>
    scanRegions.firstWhere((r) => r.id == id);
