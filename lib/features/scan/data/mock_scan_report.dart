/// Mock screening report for the scan simulation.
///
/// Nothing here is analyzed: findings come from a fixed list. A finding
/// only shows up when one of the views that would reveal it was captured,
/// and teeth no captured view shows are "not assessed", so the report
/// still responds to what the user actually photographed.
library;

import '../../dental_explorer/data/tooth_catalog.dart';
import 'capture_regions.dart';

enum ToothHealth {
  healthy('Healthy'),
  monitor('Monitor'),
  attention('Needs attention'),
  notAssessed('Not assessed');

  const ToothHealth(this.label);
  final String label;
}

class ScanFinding {
  const ScanFinding({
    required this.teeth,
    required this.location,
    required this.condition,
    required this.detail,
    required this.confidence,
    required this.health,
    required this.recommendation,
    required this.seenIn,
    this.foundIn,
  });

  /// FDI numbers.
  final List<int> teeth;
  final String location;
  final String condition;
  final String detail;

  /// 0–1.
  final double confidence;
  final ToothHealth health;
  final String recommendation;

  /// Region ids of the views that can show this, best first.
  final List<String> seenIn;

  /// The captured view it was found in. Null on the templates below.
  final String? foundIn;

  String get teethLabel => teeth.length == 1
      ? 'Tooth ${teeth.first}'
      : 'Teeth ${teeth.join(', ')}';

  ScanFinding _foundIn(String regionId) => ScanFinding(
        teeth: teeth,
        location: location,
        condition: condition,
        detail: detail,
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

/// What the report says about one tooth.
class ToothReport {
  const ToothReport({
    required this.tooth,
    required this.health,
    required this.condition,
    required this.detail,
    required this.recommendation,
    this.confidence,
    this.regionId,
  });

  final ToothInfo tooth;
  final ToothHealth health;
  final String condition;
  final String detail;
  final String recommendation;
  final double? confidence;
  final String? regionId;
}

class ScanReport {
  const ScanReport._({
    required this.id,
    required this.completedAt,
    required this.captured,
    required this.findings,
    required this.toothHealth,
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

    final health = <int, ToothHealth>{
      for (final t in ToothCatalog.all)
        t.fdi: captureRegions
                .any((r) => captured.contains(r.id) && r.covers(t))
            ? ToothHealth.healthy
            : ToothHealth.notAssessed,
    };
    for (final f in findings) {
      for (final fdi in f.teeth) {
        health[fdi] = f.health;
      }
    }

    bool found(int fdi) => findings.any((f) => f.teeth.contains(fdi));
    final attention =
        findings.where((f) => f.health == ToothHealth.attention).length;
    final monitor =
        findings.where((f) => f.health == ToothHealth.monitor).length;
    final score = (100 - attention * 10 - monitor * 2.4).round().clamp(0, 100);
    final skipped = captureRegions.length - captured.length;

    return ScanReport._(
      id: 'DS-${20480 + sequence}',
      completedAt: completedAt,
      captured: Set.unmodifiable(captured),
      findings: List.unmodifiable(findings),
      toothHealth: Map.unmodifiable(health),
      score: score,
      regionScores: {
        for (final r in captureRegions)
          r.id: captured.contains(r.id) ? _regionScores[r.id] : null,
      },
      metrics: [
        ScanMetric('plaque', 'Plaque', found(46) || found(31) ? 'Moderate' : 'Low',
            found(46) || found(31) ? MetricLevel.fair : MetricLevel.good),
        ScanMetric('gums', 'Gum Health', found(17) ? 'Fair' : 'Good',
            found(17) ? MetricLevel.fair : MetricLevel.good),
        const ScanMetric('enamel', 'Enamel', 'Good', MetricLevel.good),
        const ScanMetric('alignment', 'Alignment', 'Normal', MetricLevel.good),
        ScanMetric('cavity', 'Cavity Risk', found(36) ? 'Medium' : 'Low',
            found(36) ? MetricLevel.fair : MetricLevel.good),
        ScanMetric('staining', 'Staining', found(11) ? 'Mild' : 'None',
            found(11) ? MetricLevel.fair : MetricLevel.good),
      ],
      recommendations: [
        if (found(31))
          const ScanRecommendation(
            'lingual',
            'Brush the tongue side of your lower front teeth more carefully',
            'Hold the brush upright and use short strokes behind your lower '
                'front teeth, where tartar builds up first.',
          ),
        if (found(46) || found(17))
          const ScanRecommendation(
            'floss',
            'Floss between your back molars daily',
            "Plaque collects between molars where a brush can't reach. "
                'Floss or use interdental brushes once a day.',
          ),
        if (found(36))
          const ScanRecommendation(
            'checkup',
            'Schedule a check-up for tooth 36 within 2–4 weeks',
            'A dentist can confirm the spot and treat it early, often with '
                'a small filling.',
          ),
        if (skipped > 0)
          ScanRecommendation(
            'coverage',
            'Capture all 8 regions next time',
            '$skipped region${skipped == 1 ? ' was' : 's were'} skipped, so '
                "some teeth weren't checked.",
          ),
        if (found(11))
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
  final List<ScanFinding> findings;

  /// By FDI number.
  final Map<int, ToothHealth> toothHealth;

  /// 0–100.
  final int score;

  /// By region id; null where the region wasn't captured.
  final Map<String, int?> regionScores;
  final List<ScanMetric> metrics;
  final List<ScanRecommendation> recommendations;

  String get scoreHeadline => switch (score) {
        >= 85 => 'Excellent',
        >= 70 => 'Good',
        >= 55 => 'Fair',
        _ => 'Needs care',
      };

  String get scoreSummary => switch (score) {
        >= 85 => 'Your teeth look healthy',
        >= 70 => 'A few areas need attention',
        >= 55 => 'Several areas need care',
        _ => 'See a dentist soon',
      };

  int countOf(ToothHealth health) =>
      toothHealth.values.where((h) => h == health).length;

  ToothReport toothReport(ToothInfo tooth) {
    final health = toothHealth[tooth.fdi]!;
    for (final f in findings) {
      if (!f.teeth.contains(tooth.fdi)) continue;
      return ToothReport(
        tooth: tooth,
        health: health,
        condition: f.condition,
        detail: f.detail,
        recommendation: f.recommendation,
        confidence: f.confidence,
        regionId: f.foundIn,
      );
    }
    if (health == ToothHealth.notAssessed) {
      final suggestion = captureRegions.firstWhere((r) => r.covers(tooth));
      return ToothReport(
        tooth: tooth,
        health: health,
        condition: 'Not assessed',
        detail: "This tooth isn't visible in the views you captured.",
        recommendation:
            'Add the ${suggestion.label} view next time to include it.',
      );
    }
    final region = captureRegions
        .firstWhere((r) => captured.contains(r.id) && r.covers(tooth));
    return ToothReport(
      tooth: tooth,
      health: health,
      condition: 'Healthy',
      detail: 'No signs of decay, plaque or gum changes.',
      recommendation: _healthyAdvice[tooth.type]!,
      // Stable per tooth, 88–97%.
      confidence: 0.88 + (tooth.fdi * 7 % 10) / 100,
      regionId: region.id,
    );
  }
}

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

const _healthyAdvice = {
  ToothType.incisor:
      'Looks healthy. Keep brushing along the gumline with gentle circles.',
  ToothType.canine:
      'Looks healthy. Angle your brush around the corner of this tooth.',
  ToothType.premolar:
      'Looks healthy. Keep flossing between neighboring teeth daily.',
  ToothType.molar:
      'Looks healthy. Brush the chewing grooves well; they trap food easily.',
};

const _findingTemplates = [
  ScanFinding(
    teeth: [36],
    location: 'Lower left first molar',
    condition: 'Possible early cavity',
    detail: 'A small dark spot in the central groove of the chewing surface.',
    confidence: 0.82,
    health: ToothHealth.attention,
    recommendation: 'Book a check-up within 2–4 weeks. Caught early, a '
        'cavity can often be treated with a small filling.',
    seenIn: ['lower-occlusal', 'posterior', 'left'],
  ),
  ScanFinding(
    teeth: [46],
    location: 'Lower right first molar',
    condition: 'Plaque on biting surface',
    detail: 'A soft film along the grooves of the chewing surface.',
    confidence: 0.74,
    health: ToothHealth.monitor,
    recommendation: 'Brush the chewing surface with short back-and-forth '
        'strokes for a few extra seconds.',
    seenIn: ['lower-occlusal', 'posterior', 'right'],
  ),
  ScanFinding(
    teeth: [31, 41],
    location: 'Back of lower front teeth',
    condition: 'Tartar buildup (tongue side)',
    detail: 'Hardened deposits along the gumline on the tongue side.',
    confidence: 0.79,
    health: ToothHealth.monitor,
    recommendation: 'Tilt your brush upright to reach the tongue side. A '
        "professional cleaning removes tartar that brushing can't.",
    seenIn: ['lower-lingual'],
  ),
  ScanFinding(
    teeth: [17, 27],
    location: 'Upper back molars',
    condition: 'Mild gum recession',
    detail: 'The gumline sits slightly higher than on neighboring teeth.',
    confidence: 0.68,
    health: ToothHealth.monitor,
    recommendation: 'Use a soft-bristled brush with gentle pressure along '
        'the gumline.',
    seenIn: ['posterior', 'right', 'left', 'upper-lingual'],
  ),
  ScanFinding(
    teeth: [11, 21],
    location: 'Upper front teeth',
    condition: 'Minor surface staining',
    detail: 'Light surface discoloration, typical of coffee or tea.',
    confidence: 0.71,
    health: ToothHealth.monitor,
    recommendation: 'Rinse with water after coffee or tea. A professional '
        'polish removes surface stains.',
    seenIn: ['front'],
  ),
  ScanFinding(
    teeth: [48],
    location: 'Lower right wisdom tooth',
    condition: 'Partially erupted, monitor',
    detail: 'The crown is only partly through the gum, which can trap food.',
    confidence: 0.63,
    health: ToothHealth.monitor,
    recommendation: 'Keep the area clean and mention it at your next visit. '
        'See a dentist if it becomes sore or swollen.',
    seenIn: ['posterior', 'right', 'lower-occlusal'],
  ),
];
