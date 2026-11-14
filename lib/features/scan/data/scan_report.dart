/// Everything the results page says, worked out from one finished analysis:
/// each sign and where it is, how much of the mouth was read, and how that
/// compares with earlier scans. No widgets, so it can be tested on its own.
///
/// Nothing here adds to what the analysis said. A spot's area is a general
/// guess from where it sits in the photo; the photo with its marker stays the
/// proof. There is no health score, because nothing measured could back one.
library;

import 'dart:ui' show Rect;

import '../../screening/data/models/screening_session.dart';
import 'scan_outcomes.dart';
import 'scan_regions.dart';

/// How sure the model was about one sign, in words. Never how bad it is: the
/// model can't tell how far decay has gone.
enum SignStrength {
  faint('Faint sign'),
  possible('Possible sign'),
  strong('Strong sign');

  // Listed weakest first, the order a bar stacks them from the top.

  const SignStrength(this.label);
  final String label;

  /// From here a sign reads as strong. Below it, and above the rules' own
  /// line, it reads as possible. Faint signs come from the analysis as such.
  static const double strongFrom = 0.8;
}

/// What each strength means, in words. No figures: on a second, outside set of
/// photos signs were right less often than on the set the model trained on, so
/// a number here would claim more than has been shown.
const Map<SignStrength, String> signMeaning = {
  SignStrength.strong: 'The model is fairly sure. Worth showing a dentist.',
  SignStrength.possible:
      'The model leans yes, but it could be a stain or a shadow.',
  SignStrength.faint:
      'Often a false alarm. Mention it to a dentist if it keeps showing up.',
};

/// What can be said about one area, or one surface of it, least to most
/// pressing.
enum AreaState {
  /// No photo of it was taken.
  notTaken,

  /// A photo was saved, but no model can read that view yet.
  notRead,

  /// The only photos of it couldn't be used.
  retake,

  /// Read, and nothing was flagged.
  clear,
  faint,
  possible,
  strong;

  /// The teeth here were actually looked at.
  bool get read => index >= clear.index;

  bool get flagged => index >= faint.index;

  static AreaState of(SignStrength strength) => switch (strength) {
        SignStrength.faint => faint,
        SignStrength.possible => possible,
        SignStrength.strong => strong,
      };
}

/// The side of a tooth a photo looks at.
enum ToothSurface {
  outer('Outer'),
  biting('Biting'),
  inner('Inner');

  const ToothSurface(this.label);
  final String label;
}

/// Which surfaces each guided view looks at. Old five-region scans didn't
/// say, so they have no surface breakdown.
const Map<String, Set<ToothSurface>> _surfacesOfView = {
  'front': {ToothSurface.outer},
  'left': {ToothSurface.outer},
  'right': {ToothSurface.outer},
  'upper-occlusal': {ToothSurface.biting},
  'lower-occlusal': {ToothSurface.biting},
  'upper-lingual': {ToothSurface.inner},
  'lower-lingual': {ToothSurface.inner},
  'back-left': {ToothSurface.outer, ToothSurface.biting},
  'back-right': {ToothSurface.outer, ToothSurface.biting},
};

/// Views of an arch from straight on. Front teeth sit in the middle of the
/// photo and back teeth out to the sides, whichever way the photo is turned.
const Set<String> _archViews = {'upper-occlusal', 'lower-occlusal'};

/// Views that show both arches from one side, upper teeth above the bite.
const Set<String> _biteViews = {
  'front',
  'left',
  'right',
  'back-left',
  'back-right',
};

/// Across an arch photo, a spot this close to the middle is on a front tooth.
const double _frontBand = 0.2;

/// A spot this close to the middle of a side photo could be either arch.
const double _biteMargin = 0.06;

/// The views a mirror can't show well: back molars and inner sides.
const Set<String> hardToSeeViews = {
  'back-left',
  'back-right',
  'upper-lingual',
  'lower-lingual',
};

/// The general areas a spot could be in, from the view it's in and where it
/// sits in the photo. An arch photo can't say left from right, because a photo
/// may be turned or taken in a mirror, so a back tooth there stays both sides.
Set<MouthArea> spotAreas(ScanRegion region, Rect? box) {
  final shown = {
    for (final a in MouthArea.values)
      if (viewShowsArea(region, a)) a,
  };
  if (box == null) return shown;
  final view = baseRegionId(region.id);
  final Set<MouthArea> narrowed;
  if (_archViews.contains(view)) {
    final front = (box.center.dx - 0.5).abs() <= _frontBand;
    narrowed = shown.where((a) => a.isFront == front).toSet();
  } else if (_biteViews.contains(view) &&
      (box.center.dy - 0.5).abs() >= _biteMargin) {
    final upper = box.center.dy < 0.5;
    narrowed = shown.where((a) => a.isUpper == upper).toSet();
  } else {
    narrowed = shown;
  }
  return narrowed.isEmpty ? shown : narrowed;
}

/// Some areas in everyday words, e.g. "Upper back teeth".
String describeAreas(Set<MouthArea> areas) {
  if (areas.length == 1) return areas.single.label;
  if (areas.length == 2) {
    final [a, b] = areas.toList();
    if (a.isFront && b.isFront) return 'Front teeth';
    if (!a.isFront && !b.isFront) {
      if (a.isUpper == b.isUpper) {
        return a.isUpper ? 'Upper back teeth' : 'Lower back teeth';
      }
      if (a.isLeft == b.isLeft) {
        return a.isLeft ? 'Left back teeth' : 'Right back teeth';
      }
    }
  }
  if (areas.length == 3 && areas.every((a) => a.isUpper)) return 'Upper teeth';
  if (areas.length == 3 && areas.every((a) => !a.isUpper)) return 'Lower teeth';
  return areas.map((a) => a.label).join(', ');
}

/// One thing the analysis marked in one photo.
class ReportSpot {
  const ReportSpot({
    required this.finding,
    required this.photo,
    required this.strength,
    required this.areas,
  });

  final ScreeningFinding finding;

  /// The photo it's in.
  final ScanRegion photo;
  final SignStrength strength;
  final Set<MouthArea> areas;

  String get photoId => photo.id;

  /// Where it is in the photo, each side 0-1.
  Rect? get box => boxOf(finding);

  /// The model's own confidence, or null if it didn't report one.
  int? get percent => switch (finding.confidence) {
        final c? => (c * 100).round(),
        null => null,
      };

  String get where => describeAreas(areas);

  static Rect? boxOf(ScreeningFinding finding) => switch (finding.bbox) {
        [final x, final y, final w, final h] => Rect.fromLTWH(x, y, w, h),
        _ => null,
      };
}

/// One area of the mouth: what was seen there, and in which photos.
class AreaReport {
  const AreaReport({
    required this.area,
    required this.state,
    required this.spots,
    required this.photoIds,
  });

  final MouthArea area;
  final AreaState state;
  final List<ReportSpot> spots;

  /// The photos that show this area.
  final List<String> photoIds;
}

/// When the analysis says to see a dentist, least to most pressing.
enum ReportLevel { none, nextVisit, soon, prompt }

/// What a row of the chart by type counts.
enum ConditionKind { sign, faint, dentalWork, notRead }

/// One kind of thing the check looks for, and how much of it was marked.
class ConditionRow {
  const ConditionRow(
    this.name,
    this.note, {
    required this.kind,
    this.count,
    this.strong = 0,
  });

  final String name;
  final ConditionKind kind;

  /// What the count means, in a few words.
  final String note;

  /// How many were marked, or null for something this check can't read.
  final int? count;

  /// Of [count], how many were strong signs.
  final int strong;
}

/// One finished analysis, for the results page.
class ScreeningReport {
  ScreeningReport(this.analysis, List<String> photoIds)
      : photoIds = List.unmodifiable(photoIds),
        outcomes = outcomesOf(analysis, photoIds) {
    spots = List.unmodifiable([
      ..._spotsFrom(analysis.findings, faint: false),
      ..._spotsFrom(analysis.faintFindings, faint: true),
    ]);
    areas = {for (final a in MouthArea.values) a: _areaReport(a)};
  }

  final ScreeningAnalysis analysis;
  final List<String> photoIds;

  /// What the analysis said about each photo.
  final Map<String, ViewOutcome> outcomes;

  /// Every sign, the ones acted on first, each group most confident first.
  late final List<ReportSpot> spots;
  late final Map<MouthArea, AreaReport> areas;

  /// The service ran without a trained model, so nothing was really looked for.
  bool get detectorOff => analysis.model?.startsWith('det-none') ?? false;

  /// Signs the rules acted on.
  int get signCount => analysis.findings.length;

  int countOf(SignStrength strength) =>
      spots.where((s) => s.strength == strength).length;

  /// The photos with a sign in them, the one with the most confident first.
  List<String> get photosWithSigns =>
      spots.map((s) => s.photoId).toSet().toList();

  int get faintCount => analysis.faintFindings.length;

  int get photosRead => outcomes.values.where((o) => o.checked).length;

  int get photosToRetake =>
      outcomes.values.where((o) => o == ViewOutcome.retake).length;

  int get areasRead => areas.values.where((a) => a.state.read).length;

  ReportLevel get level {
    var level = ReportLevel.none;
    for (final r in analysis.recommendations) {
      if (r.code == 'braces_seen') continue;
      final next = switch (r.urgency) {
        'prompt' => ReportLevel.prompt,
        'soon' => ReportLevel.soon,
        _ => ReportLevel.nextVisit,
      };
      if (next.index > level.index) level = next;
    }
    return level;
  }

  /// The result in a few words, built from what the rules said.
  String get headline {
    if (photosRead == 0) {
      return photosToRetake > 0
          ? "We couldn't read these photos"
          : 'Your photos are saved';
    }
    return switch (level) {
      ReportLevel.prompt => 'See a dentist promptly',
      ReportLevel.soon => 'Book a dental visit soon',
      ReportLevel.nextVisit => 'Mention this at your next visit',
      ReportLevel.none when faintCount > 0 => 'Nothing to act on right now',
      ReportLevel.none => 'Nothing flagged in your photos',
    };
  }

  /// What was found, in a few words. What to do about it is said separately.
  String get findingLine {
    if (photosRead == 0) return headline;
    final n = signCount;
    if (n > 0) return '$n possible ${n == 1 ? 'sign' : 'signs'} of decay';
    if (faintCount > 0) {
      return '$faintCount faint ${faintCount == 1 ? 'sign' : 'signs'} to watch';
    }
    return 'Nothing flagged in your photos';
  }

  /// The confidence the model gave its signs, lowest and highest. Null if it
  /// marked nothing or reported no confidence.
  (int, int)? get confidenceRange {
    final all = [
      for (final s in spots)
        if (s.percent case final p?) p,
    ];
    if (all.isEmpty) return null;
    return (
      all.reduce((a, b) => a < b ? a : b),
      all.reduce((a, b) => a > b ? a : b),
    );
  }

  /// This scan used the guided views, rather than the old five regions.
  bool get guided => coverage != null;

  /// Guided views with at least one photo read. An old scan counts its photos.
  int get viewsRead => guided
      ? scanRegions
          .where((r) =>
              (outcomes[r.id]?.checked ?? false) ||
              (outcomes[secondPhotoId(r.id)]?.checked ?? false))
          .length
      : photosRead;

  /// What [viewsRead] is out of.
  int get viewsTotal => guided ? scanRegions.length : photoIds.length;

  int get areasFlagged => areas.values.where((a) => a.state.flagged).length;

  /// Areas with a sign the advice is based on.
  int get areasToCheck => areas.values
      .where(
          (a) => a.state == AreaState.possible || a.state == AreaState.strong)
      .length;

  /// Areas with only a faint sign.
  int get areasToWatch =>
      areas.values.where((a) => a.state == AreaState.faint).length;

  /// Areas read with nothing marked.
  int get areasClear =>
      areas.values.where((a) => a.state == AreaState.clear).length;

  /// Areas no photo could speak for: none taken, none usable, or none read yet.
  int get areasUnread => areas.values.where((a) => !a.state.read).length;

  /// What the check looked for and how much of each it marked, for the chart
  /// by type. What it can't read is listed too, with no count, so a short list
  /// is never taken for a clean one.
  List<ConditionRow> get conditions {
    final counted = spots.where((s) => s.strength != SignStrength.faint);
    final labels = {for (final s in counted) s.finding.label};
    return [
      if (labels.isEmpty)
        const ConditionRow(
          'Possible tooth decay',
          'Nothing marked in the photos read',
          kind: ConditionKind.sign,
          count: 0,
        )
      else
        for (final label in labels)
          ConditionRow(
            label,
            'The signs your advice is based on',
            kind: ConditionKind.sign,
            count: counted.where((s) => s.finding.label == label).length,
            strong: counted
                .where((s) =>
                    s.finding.label == label &&
                    s.strength == SignStrength.strong)
                .length,
          ),
      ConditionRow(
        'Faint signs',
        'Too unsure to act on. Compared on your next scan',
        kind: ConditionKind.faint,
        count: faintCount,
      ),
      // Only said when seen: not every model looks for dental work.
      if (analysis.dentalWork.isNotEmpty)
        ConditionRow(
          'Fillings and crowns',
          'Told apart from decay. Not a concern',
          kind: ConditionKind.dentalWork,
          count: analysis.dentalWork.length,
        ),
      const ConditionRow(
        'Plaque and tartar',
        'Not read by this check yet',
        kind: ConditionKind.notRead,
      ),
      const ConditionRow(
        'Gum problems',
        'Not read by this check yet',
        kind: ConditionKind.notRead,
      ),
    ];
  }

  /// For each surface, in order: how many of its six areas were read, and how
  /// many have a saved photo no model can read. Null for an old five-region scan.
  List<(ToothSurface, int read, int unread)>? get surfaces {
    final cells = coverage;
    if (cells == null) return null;
    return [
      for (final surface in ToothSurface.values)
        (
          surface,
          MouthArea.values.where((a) => cells[(surface, a)]!.read).length,
          MouthArea.values
              .where((a) => cells[(surface, a)] == AreaState.notRead)
              .length,
        ),
    ];
  }

  /// The fillings and crowns seen, in words, e.g. "2 fillings and 1 crown".
  String? get dentalWorkLine {
    int count(String word) => analysis.dentalWork
        .where((f) => f.label.toLowerCase().contains(word))
        .length;
    String named(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
    final fillings = count('filling'), crowns = count('crown');
    return switch ((fillings, crowns)) {
      (0, 0) => null,
      (_, 0) => named(fillings, 'filling'),
      (0, _) => named(crowns, 'crown'),
      _ => '${named(fillings, 'filling')} and ${named(crowns, 'crown')}',
    };
  }

  /// Daily habits that fit what this scan saw, in one short line each.
  List<String> get careTips {
    final flagged = [
      for (final a in areas.values)
        if (a.state.flagged) a.area,
    ];
    return [
      if (flagged.any((a) => !a.isFront))
        'Angle your brush to reach your back teeth.'
      else if (flagged.isNotEmpty)
        'Take extra care along the gumline of your front teeth.',
      'Brush twice a day with fluoride toothpaste, and floss.',
    ];
  }

  /// Worth asking at the next visit, so a sign turns into a real answer.
  List<String> get dentistQuestions => [
        if (signCount > 0) ...[
          'Is this decay, a stain, or something else?',
          'Does it need treatment now, or can we watch it?',
        ] else if (faintCount > 0) ...[
          'Is this spot anything to watch?',
          'Would fluoride or sealants help me?',
        ] else ...[
          'Is there anything an X-ray should check?',
          'Would fluoride or sealants help me?',
        ],
      ];

  /// The result as plain text, to paste into a message to a dentist. What the
  /// user [reported] is kept under its own heading.
  String summaryForDentist(String date, {List<String> reported = const []}) {
    final lines = [
      'DENTRA screening, $date. Not a diagnosis.',
      '$photosRead of ${photoIds.length} photos read.',
      if (spots.isEmpty) 'Nothing flagged.',
      for (final s in spots)
        '- ${s.finding.label}: ${s.where}, ${s.strength.label.toLowerCase()}'
            '${s.percent == null ? '' : ' (${s.percent}% model confidence)'}, '
            'in the ${s.photo.label} photo.',
      if (dentalWorkLine case final work?) 'Also seen: $work.',
      'Not read by this check: plaque, tartar, gums, inner sides.',
      if (reported.isNotEmpty) ...[
        '',
        'What I told DENTRA (my own words, not detected by the check):',
        for (final line in reported) '- $line',
      ],
    ];
    return lines.join('\n');
  }

  /// The result in one plain sentence. Unread photos keep the service's own
  /// words, which say what to do about them.
  String get sentence {
    if (photosRead == 0) return analysis.summary;
    final n = signCount;
    if (n > 0) {
      final where = describeAreas({
        for (final s in spots)
          if (s.strength != SignStrength.faint) ...s.areas,
      });
      final place = where.contains(',') ? 'a few areas' : where.toLowerCase();
      return '$n ${n == 1 ? 'sign' : 'signs'} of possible decay in $place. '
          'This is a screening, not a diagnosis.';
    }
    if (faintCount > 0) {
      return '$faintCount faint ${faintCount == 1 ? 'sign' : 'signs'}, too '
          'unsure to act on. We\'ll compare next scan.';
    }
    return 'Nothing flagged in the $photosRead '
        '${photosRead == 1 ? 'photo' : 'photos'} we could read. This check can '
        'miss early decay, so keep your regular check-ups.';
  }

  /// Each area against each surface, or null for an old five-region scan.
  late final Map<(ToothSurface, MouthArea), AreaState>? coverage = () {
    if (photoIds.any((id) => !_surfacesOfView.containsKey(baseRegionId(id)))) {
      return null;
    }
    return {
      for (final surface in ToothSurface.values)
        for (final area in MouthArea.values)
          (surface, area): _surfaceState(surface, area),
    };
  }();

  /// The photos of [surface] in [area], whatever came of them.
  List<String> _photosOf(ToothSurface surface, MouthArea area) => [
        for (final id in photoIds)
          if ((_surfacesOfView[baseRegionId(id)]?.contains(surface) ?? false) &&
              viewShowsArea(findScanRegion(id)!, area))
            id,
      ];

  AreaState _surfaceState(ToothSurface surface, MouthArea area) {
    final photos = _photosOf(surface, area);
    return _stateOf(
      spots.where((s) => photos.contains(s.photoId) && s.areas.contains(area)),
      photos,
    );
  }

  AreaReport _areaReport(MouthArea area) {
    final found = spots.where((s) => s.areas.contains(area)).toList();
    final photos = [
      for (final id in photoIds)
        if (findScanRegion(id) case final region?
            when viewShowsArea(region, area))
          id,
    ];
    return AreaReport(
      area: area,
      state: _stateOf(found, photos),
      spots: List.unmodifiable(found),
      photoIds: List.unmodifiable(photos),
    );
  }

  AreaState _stateOf(Iterable<ReportSpot> found, List<String> photos) {
    var state = AreaState.notTaken;
    for (final s in found) {
      final next = AreaState.of(s.strength);
      if (next.index > state.index) state = next;
    }
    if (state.flagged) return state;
    for (final id in photos) {
      final next = switch (outcomes[id]) {
        ViewOutcome.notChecked => AreaState.notRead,
        ViewOutcome.retake => AreaState.retake,
        null => AreaState.notTaken,
        // A sign elsewhere in the photo says nothing about this area.
        _ => AreaState.clear,
      };
      if (next.index > state.index) state = next;
    }
    return state;
  }

  static List<ReportSpot> _spotsFrom(
    List<ScreeningFinding> findings, {
    required bool faint,
  }) {
    final found = <ReportSpot>[];
    for (final f in findings) {
      final region = switch (f.regionId) {
        final id? => findScanRegion(id),
        null => null,
      };
      if (region == null) continue;
      found.add(ReportSpot(
        finding: f,
        photo: region,
        strength: faint
            ? SignStrength.faint
            : (f.confidence ?? 0) >= SignStrength.strongFrom
                ? SignStrength.strong
                : SignStrength.possible,
        areas: spotAreas(region, ReportSpot.boxOf(f)),
      ));
    }
    found.sort((a, b) =>
        (b.finding.confidence ?? 0).compareTo(a.finding.confidence ?? 0));
    return found;
  }
}

/// One past scan on the timeline.
class TrendPoint {
  const TrendPoint({
    required this.sessionId,
    required this.at,
    required this.report,
  });

  final String sessionId;
  final DateTime at;
  final ScreeningReport report;
}

/// How a scan compares with the ones before it. Only scans that really read
/// some photos count, and an area is only compared when both scans read it.
class ScanTrend {
  ScanTrend._(this.points);

  /// Oldest first, ending at the scan the page is about.
  final List<TrendPoint> points;

  /// Most scans the chart has room for.
  static const int maxPoints = 8;

  /// [sessions] newest first. [currentId] is the scan the page is about; null
  /// means the newest.
  factory ScanTrend.of(List<ScreeningSession> sessions, {String? currentId}) {
    final start =
        currentId == null ? 0 : sessions.indexWhere((s) => s.id == currentId);
    final points = <TrendPoint>[];
    for (final s in sessions.skip(start < 0 ? 0 : start)) {
      final analysis = s.analysis;
      if (analysis == null || analysis.status != AnalysisStatus.complete) {
        continue;
      }
      final report = ScreeningReport(analysis, s.capturedRegions);
      if (report.detectorOff || report.photosRead == 0) continue;
      points
          .add(TrendPoint(sessionId: s.id, at: s.completedAt, report: report));
      if (points.length == maxPoints) break;
    }
    return ScanTrend._(List.unmodifiable(points.reversed));
  }

  bool get hasHistory => points.length >= 2;

  /// Some scans here came from an earlier version of the check, so a change may
  /// come from the check rather than the teeth.
  bool get mixedVersions =>
      points.map((p) => _detectorOf(p.report)).toSet().length > 1;

  static String? _detectorOf(ScreeningReport r) =>
      r.analysis.model?.split('+').first;

  /// Flagged in this scan and the one before.
  List<MouthArea> get stillAreas =>
      _compare((now, then) => now.flagged && then.flagged);

  ScreeningReport? get _now => points.isEmpty ? null : points.last.report;

  ScreeningReport? get _before =>
      points.length < 2 ? null : points[points.length - 2].report;

  List<MouthArea> _compare(bool Function(AreaState now, AreaState then) test) {
    final now = _now, then = _before;
    if (now == null || then == null) return const [];
    return [
      for (final a in MouthArea.values)
        if (now.areas[a]!.state.read &&
            then.areas[a]!.state.read &&
            test(now.areas[a]!.state, then.areas[a]!.state))
          a,
    ];
  }

  /// Flagged now and not last time.
  List<MouthArea> get newAreas =>
      _compare((now, then) => now.flagged && !then.flagged);

  /// Flagged last time and not now.
  List<MouthArea> get clearedAreas =>
      _compare((now, then) => !now.flagged && then.flagged);

  /// Areas flagged in this scan and at least the two scans before it in a row:
  /// faint or not, something that keeps showing up is worth a dentist's look.
  /// Read-less scans don't break a run, since they say nothing either way.
  Map<MouthArea, int> get repeating {
    final out = <MouthArea, int>{};
    for (final area in MouthArea.values) {
      var run = 0;
      for (final p in points.reversed) {
        final state = p.report.areas[area]!.state;
        if (state.flagged) {
          run++;
        } else if (state.read) {
          break;
        }
      }
      if (run >= 3) out[area] = run;
    }
    return out;
  }
}
