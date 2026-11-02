/// What the real analysis said about each photo and each area of the mouth.
///
/// Everyone's mouth is different (missing teeth, extra teeth, crowding), and
/// pinpointing a single tooth from phone photos isn't reliable, so results
/// stay at the level of a photo or one of six general areas, never a tooth.
library;

import '../../dental_explorer/data/tooth_catalog.dart';
import '../../screening/data/models/screening_session.dart';
import 'scan_regions.dart';

/// Six general areas: each arch split into left back, front and right back
/// (the user's own left and right).
enum MouthArea {
  upperRight('Upper right back'),
  upperFront('Upper front'),
  upperLeft('Upper left back'),
  lowerLeft('Lower left back'),
  lowerFront('Lower front'),
  lowerRight('Lower right back');

  const MouthArea(this.label);
  final String label;

  bool get isUpper => index <= upperLeft.index;
  bool get isFront => this == upperFront || this == lowerFront;
  bool get isLeft => this == upperLeft || this == lowerLeft;

  /// The area a tooth position belongs to.
  static MouthArea at(DentalArch arch, DentalSide side, ToothKind kind) {
    final upper = arch == DentalArch.upper;
    if (!kind.isPosterior) return upper ? upperFront : lowerFront;
    final left = side == DentalSide.left;
    return upper ? (left ? upperLeft : upperRight) : (left ? lowerLeft : lowerRight);
  }

  /// The area a tooth of the reference model belongs to.
  static MouthArea of(ToothInfo tooth) {
    final upper = tooth.arch == ToothArch.upper;
    if (tooth.position <= 3) return upper ? upperFront : lowerFront;
    final right = tooth.side == ToothSide.right;
    return upper
        ? (right ? upperRight : upperLeft)
        : (right ? lowerRight : lowerLeft);
  }

  bool contains(ToothInfo tooth) => of(tooth) == this;
}

/// One photo's result, least to most pressing. [retake] and [notChecked] mean
/// the photo says nothing about the teeth, so they rank below [clear].
enum ViewOutcome {
  notChecked,
  retake,
  clear,
  finding,
  urgent;

  /// Says something about the teeth themselves.
  bool get checked => index >= clear.index;
}

/// The note about braces describes the check, not the teeth.
const String _bracesNote = 'braces_seen';

/// What the finished analysis said about each of [photoIds].
Map<String, ViewOutcome> outcomesOf(
  ScreeningAnalysis analysis,
  Iterable<String> photoIds,
) {
  ViewOutcome outcome(String id) {
    if (analysis.qualityIssues
        .any((i) => i.regionId == id && i.modality == 'rgb')) {
      return ViewOutcome.retake;
    }
    if (findScanRegion(id)?.checked == false) return ViewOutcome.notChecked;
    final base = baseRegionId(id);
    final notes = [
      for (final r in analysis.recommendations)
        if (r.code != _bracesNote && r.regionIds.contains(base)) r,
    ];
    // Findings name the exact photo; advice only names its view.
    final found = analysis.findings.isEmpty
        ? notes.isNotEmpty
        : analysis.findings.any((f) => f.regionId == id);
    if (!found) return ViewOutcome.clear;
    return notes.any((r) => r.urgency != 'routine')
        ? ViewOutcome.urgent
        : ViewOutcome.finding;
  }

  return {for (final id in photoIds) id: outcome(id)};
}

/// A view counts for an area when it's meant to show most of its teeth, so a
/// side photo reaching one canine says nothing about the front.
bool viewShowsArea(ScanRegion region, MouthArea area) {
  final teeth = [
    for (final t in ToothCatalog.all)
      if (area.contains(t)) t,
  ];
  return teeth.where(region.covers).length * 2 >= teeth.length;
}

/// The most that any photo showing [area] said about it, or null when no
/// photo shows it.
ViewOutcome? areaOutcome(MouthArea area, Map<String, ViewOutcome> outcomes) {
  ViewOutcome? best;
  outcomes.forEach((id, outcome) {
    final region = findScanRegion(id);
    if (region == null || !viewShowsArea(region, area)) return;
    if (best == null || outcome.index > best!.index) best = outcome;
  });
  return best;
}
