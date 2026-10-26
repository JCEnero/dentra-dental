/// Mock screening report for the scan simulation.
///
/// Everyone's mouth is different (missing teeth, extra teeth, crowding),
/// and pinpointing a single tooth from phone photos isn't reliable, so
/// results describe general areas of the mouth ("we detected a possible
/// early cavity in your lower left back teeth"), never numbered teeth.
///
/// Nothing here is analyzed: findings come from a fixed list. A finding
/// only shows up when one of the views that would reveal it was captured,
/// and areas no captured view shows are "not checked", so the report
/// still responds to what the user actually photographed.
library;

import '../../dental_explorer/data/tooth_catalog.dart';
import 'capture_regions.dart';

/// Six general areas: each arch split into left back, front and right
/// back (the user's own left and right).
enum MouthArea {
  upperRight('Upper right back teeth', 'Upper right'),
  upperFront('Upper front teeth', 'Upper front'),
  upperLeft('Upper left back teeth', 'Upper left'),
  lowerLeft('Lower left back teeth', 'Lower left'),
  lowerFront('Lower front teeth', 'Lower front'),
  lowerRight('Lower right back teeth', 'Lower right');

  const MouthArea(this.label, this.shortLabel);
  final String label;
  final String shortLabel;

  ToothArch get arch => index < 3 ? ToothArch.upper : ToothArch.lower;

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

enum AreaHealth {
  healthy('Healthy'),
  monitor('Monitor'),
  attention('Needs attention'),
  notChecked('Not checked');

  const AreaHealth(this.label);
  final String label;
}

class ScanFinding {
  const ScanFinding({
    required this.area,
    required this.condition,
    required this.summary,
    required this.confidence,
    required this.health,
    required this.recommendation,
    required this.seenIn,
    this.foundIn,
  });

  final MouthArea area;
  final String condition;

  /// What was seen, in a sentence about the area, e.g. "We detected a
  /// possible early cavity on … your lower left back teeth."
  final String summary;

  /// 0–1.
  final double confidence;
  final AreaHealth health;
  final String recommendation;

  /// Region ids of the views that can show this, best first.
  final List<String> seenIn;

  /// The captured view it was found in. Null on the templates below.
  final String? foundIn;

  ScanFinding _foundIn(String regionId) => ScanFinding(
        area: area,
        condition: condition,
        summary: summary,
        confidence: confidence,
        health: health,
        recommendation: recommendation,
        seenIn: seenIn,
        foundIn: regionId,
      );
}

enum MetricLevel { good, fair, poor }

class ScanMetric {
  const ScanMetric(this.id, this.label, this.value, this.level);
  final String id;
  final String label;
  final String value;
  final MetricLevel level;
}

class ScanRecommendation {
  const ScanRecommendation(this.id, this.title, this.body);
  final String id;
  final String title;
  final String body;
}

class ScanReport {
  const ScanReport._({
    required this.id,
    required this.completedAt,
    required this.captured,
    required this.findings,
    required this.areaHealth,
    required this.score,
    required this.regionScores,
    required this.metrics,
    required this.recommendations,
  });

  /// Builds the report for a scan of the [captured] region ids.
  /// [sequence] numbers scans in this session, starting at 1.
  factory ScanReport.generate({
    required Set<String> captured,
    required DateTime completedAt,
    required int sequence,
  }) {
    final findings = [
      for (final f in _findingTemplates)
        if (f.seenIn.where(captured.contains).firstOrNull case final id?)
          f._foundIn(id),
    ];

    // An area is checked when some captured view shows part of it.
    final health = <MouthArea, AreaHealth>{
      for (final area in MouthArea.values)
        area: captureRegions.any((r) =>
                captured.contains(r.id) &&
                ToothCatalog.all.any((t) => area.contains(t) && r.covers(t)))
            ? AreaHealth.healthy
            : AreaHealth.notChecked,
    };
    for (final f in findings) {
      // The most serious finding in an area decides its status.
      if (health[f.area] != AreaHealth.attention) health[f.area] = f.health;
    }

    bool found(String condition) =>
        findings.any((f) => f.condition == condition);
    final attention =
        findings.where((f) => f.health == AreaHealth.attention).length;
    final monitor =
        findings.where((f) => f.health == AreaHealth.monitor).length;
    final score = (100 - attention * 10 - monitor * 3).clamp(0, 100);
    final skipped = captureRegions.length - captured.length;
    final plaque = found(_plaque) || found(_tartar);

    return ScanReport._(
      id: 'DS-${20480 + sequence}',
      completedAt: completedAt,
      captured: Set.unmodifiable(captured),
      findings: List.unmodifiable(findings),
      areaHealth: Map.unmodifiable(health),
      score: score,
      regionScores: {
        for (final r in captureRegions)
          r.id: captured.contains(r.id) ? _regionScores[r.id] : null,
      },
      metrics: [
        ScanMetric('plaque', 'Plaque', plaque ? 'Moderate' : 'Low',
            plaque ? MetricLevel.fair : MetricLevel.good),
        ScanMetric('gums', 'Gum Health', found(_recession) ? 'Fair' : 'Good',
            found(_recession) ? MetricLevel.fair : MetricLevel.good),
        const ScanMetric('enamel', 'Enamel', 'Good', MetricLevel.good),
        const ScanMetric('alignment', 'Alignment', 'Normal', MetricLevel.good),
        ScanMetric('cavity', 'Cavity Risk', found(_cavity) ? 'Medium' : 'Low',
            found(_cavity) ? MetricLevel.fair : MetricLevel.good),
        ScanMetric('staining', 'Staining', found(_staining) ? 'Mild' : 'None',
            found(_staining) ? MetricLevel.fair : MetricLevel.good),
      ],
      recommendations: [
        if (found(_tartar))
          const ScanRecommendation(
            'lingual',
            'Brush the tongue side of your lower front teeth more carefully',
            'Hold the brush upright and use short strokes behind your lower '
                'front teeth, where tartar builds up first.',
          ),
        if (found(_plaque) || found(_recession))
          const ScanRecommendation(
            'floss',
            'Floss between your back teeth daily',
            "Plaque collects between back teeth where a brush can't reach. "
                'Floss or use interdental brushes once a day.',
          ),
        if (found(_cavity))
          const ScanRecommendation(
            'checkup',
            'Have your lower left back teeth checked within 2–4 weeks',
            'A dentist can confirm the spot and treat it early, often with '
                'a small filling.',
          ),
        if (skipped > 0)
          ScanRecommendation(
            'coverage',
            'Capture all 8 regions next time',
            '$skipped region${skipped == 1 ? ' was' : 's were'} skipped, so '
                "some areas weren't checked.",
          ),
        if (found(_staining))
          const ScanRecommendation(
            'stain',
            'Rinse with water after coffee or tea',
            'A quick rinse helps keep surface stains from setting in.',
          ),
        const ScanRecommendation(
          'routine',
          'Keep up twice-daily brushing',
          'Two minutes, twice a day, with a fluoride toothpaste.',
        ),
      ].take(4).toList(growable: false),
    );
  }

  /// e.g. "DS-20481".
  final String id;
  final DateTime completedAt;
  final Set<String> captured;

  /// Most serious first.
  final List<ScanFinding> findings;
  final Map<MouthArea, AreaHealth> areaHealth;

  /// 0–100.
  final int score;

  /// By region id; null where the region wasn't captured.
  final Map<String, int?> regionScores;
  final List<ScanMetric> metrics;
  final List<ScanRecommendation> recommendations;

  /// Half or more of the areas weren't in any photo, so a high score
  /// would mostly reflect what wasn't seen.
  bool get isPartial =>
      countOf(AreaHealth.notChecked) * 2 >= MouthArea.values.length;

  String get scoreHeadline => isPartial
      ? 'Partial scan'
      : switch (score) {
          >= 85 => 'Excellent',
          >= 70 => 'Good',
          >= 55 => 'Fair',
          _ => 'Needs care',
        };

  String get scoreSummary => isPartial
      ? 'Add more views for a full picture'
      : switch (score) {
          >= 85 => 'Your teeth look healthy',
          >= 70 => 'A few areas need attention',
          >= 55 => 'Several areas need care',
          _ => 'See a dentist soon',
        };

  /// Areas with this status.
  int countOf(AreaHealth health) =>
      areaHealth.values.where((h) => h == health).length;

}

const _cavity = 'Possible early cavity';
const _plaque = 'Plaque buildup';
const _tartar = 'Tartar buildup';
const _recession = 'Mild gum recession';
const _staining = 'Minor surface staining';

const _regionScores = {
  'front': 88,
  'upper-occlusal': 82,
  'lower-occlusal': 70,
  'left': 80,
  'right': 76,
  'upper-lingual': 84,
  'lower-lingual': 65,
  'posterior': 72,
};

const _findingTemplates = [
  ScanFinding(
    area: MouthArea.lowerLeft,
    condition: _cavity,
    summary: 'We detected a possible early cavity on the chewing surface '
        'of your lower left back teeth.',
    confidence: 0.82,
    health: AreaHealth.attention,
    recommendation: 'Have this area checked within 2–4 weeks. Caught early, '
        'a cavity can often be treated with a small filling.',
    seenIn: ['lower-occlusal', 'posterior', 'left'],
  ),
  ScanFinding(
    area: MouthArea.lowerRight,
    condition: _plaque,
    summary: 'We noticed plaque building up on the chewing surfaces of '
        'your lower right back teeth.',
    confidence: 0.74,
    health: AreaHealth.monitor,
    recommendation: 'Brush the chewing surfaces with short back-and-forth '
        'strokes for a few extra seconds.',
    seenIn: ['lower-occlusal', 'posterior', 'right'],
  ),
  ScanFinding(
    area: MouthArea.lowerFront,
    condition: _tartar,
    summary: 'We detected tartar along the tongue side of your lower '
        'front teeth.',
    confidence: 0.79,
    health: AreaHealth.monitor,
    recommendation: 'Tilt your brush upright to reach the tongue side. A '
        "professional cleaning removes tartar that brushing can't.",
    seenIn: ['lower-lingual'],
  ),
  ScanFinding(
    area: MouthArea.upperRight,
    condition: _recession,
    summary: 'The gumline around your upper right back teeth may be '
        'pulling back slightly.',
    confidence: 0.68,
    health: AreaHealth.monitor,
    recommendation: 'Use a soft-bristled brush with gentle pressure along '
        'the gumline.',
    seenIn: ['posterior', 'right', 'upper-lingual'],
  ),
  ScanFinding(
    area: MouthArea.upperFront,
    condition: _staining,
    summary: 'We noticed light surface staining on your upper front '
        'teeth, typical of coffee or tea.',
    confidence: 0.71,
    health: AreaHealth.monitor,
    recommendation: 'Rinse with water after coffee or tea. A professional '
        'polish removes surface stains.',
    seenIn: ['front'],
  ),
];
