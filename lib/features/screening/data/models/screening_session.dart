import '../../../dental_profile/data/models/dental_answers.dart';

/// A finished scan session, as recorded in the user's screening history.
///
/// JSON keys match the `screening_sessions` / `screening_captures` /
/// `screening_findings` tables in `database/schema.sql`, so the same shape
/// serves the local store and the future API. Older local records written
/// before this change (camelCase keys, no captures) still load.
///
/// Images are not part of this record: on the backend they live in object
/// storage and arrive as [ScreeningCapture.imageUrl]. Until then they are
/// kept in memory for the current app run only.
class ScreeningSession {
  final String id;

  /// Owner (users.id). Null for records made before accounts existed.
  final String? userId;
  final DateTime completedAt;

  /// Region ids (see `scanRegions`) that were captured, in capture order.
  final List<String> capturedRegions;
  final int totalRegions;

  /// Per-region capture details. Empty for older records.
  final List<ScreeningCapture> captures;

  /// AI analysis, only when an analysis service actually returned one.
  final ScreeningAnalysis? analysis;

  /// What the user had reported in their dental profile when this
  /// screening was saved. Self-reported, never a finding: show it apart
  /// from [analysis]. Set by the server; null without a profile.
  final ScreeningReportedContext? reportedContext;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ScreeningSession({
    required this.id,
    required this.completedAt,
    required this.capturedRegions,
    required this.totalRegions,
    this.userId,
    this.captures = const [],
    this.analysis,
    this.reportedContext,
    this.createdAt,
    this.updatedAt,
  });

  bool get isComplete => capturedRegions.length >= totalRegions;

  ScreeningStatus get status =>
      isComplete ? ScreeningStatus.complete : ScreeningStatus.partial;

  ScreeningCapture? captureFor(String regionId) {
    for (final c in captures) {
      if (c.regionId == regionId) return c;
    }
    return null;
  }

  ScreeningSession copyWith({
    String? userId,
    List<ScreeningCapture>? captures,
    ScreeningAnalysis? analysis,
    DateTime? updatedAt,
  }) {
    return ScreeningSession(
      id: id,
      userId: userId ?? this.userId,
      completedAt: completedAt,
      capturedRegions: capturedRegions,
      totalRegions: totalRegions,
      captures: captures ?? this.captures,
      analysis: analysis ?? this.analysis,
      reportedContext: reportedContext,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'completed_at': completedAt.toUtc().toIso8601String(),
        'captured_regions': capturedRegions,
        'total_regions': totalRegions,
        'status': status.name,
        'captures': captures.map((c) => c.toJson()).toList(),
        'analysis': analysis?.toJson(),
        'reported_context': reportedContext?.toJson(),
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  factory ScreeningSession.fromJson(Map<String, dynamic> json) {
    // Reads both snake_case (current) and camelCase (v1 local records).
    T? pick<T>(String snake, String camel) =>
        (json[snake] ?? json[camel]) as T?;
    DateTime? date(String snake, [String? camel]) {
      final v = pick<String>(snake, camel ?? snake);
      return v == null ? null : DateTime.tryParse(v)?.toLocal();
    }

    final analysis = json['analysis'];
    final context = json['reported_context'];
    return ScreeningSession(
      id: json['id'] as String,
      userId: pick<String>('user_id', 'userId'),
      completedAt: date('completed_at', 'completedAt')!,
      capturedRegions: (pick<List<dynamic>>('captured_regions', 'capturedRegions') ??
              const [])
          .cast<String>(),
      totalRegions: pick<int>('total_regions', 'totalRegions') ?? 0,
      captures: ((json['captures'] as List<dynamic>?) ?? const [])
          .map((e) => ScreeningCapture.fromJson(e as Map<String, dynamic>))
          .toList(),
      analysis: analysis == null
          ? null
          : ScreeningAnalysis.fromJson(analysis as Map<String, dynamic>),
      reportedContext: context == null
          ? null
          : ScreeningReportedContext.fromJson(context as Map<String, dynamic>),
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
    );
  }
}

enum ScreeningStatus {
  complete('Complete'),
  partial('Partial');

  const ScreeningStatus(this.label);
  final String label;
}

/// One captured region of a session.
class ScreeningCapture {
  final String regionId;

  /// 'device', 'phoneCamera' or 'photoLibrary' (see `CaptureSource`).
  final String source;
  final DateTime capturedAt;

  /// Set once the backend stores the image. Null for local-only records.
  final String? imageUrl;

  const ScreeningCapture({
    required this.regionId,
    required this.source,
    required this.capturedAt,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'region_id': regionId,
        'source': source,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'image_url': imageUrl,
      };

  factory ScreeningCapture.fromJson(Map<String, dynamic> json) =>
      ScreeningCapture(
        regionId: json['region_id'] as String,
        source: json['source'] as String? ?? 'phoneCamera',
        capturedAt: DateTime.parse(json['captured_at'] as String).toLocal(),
        imageUrl: json['image_url'] as String?,
      );
}

/// AI-assisted analysis of a session. Never a diagnosis.
class ScreeningAnalysis {
  /// Plain-language summary returned by the analysis service.
  final String summary;

  /// Structured findings, when the service provides them.
  final List<ScreeningFinding> findings;
  final DateTime analyzedAt;

  /// Identifies the model/version that produced the result, for audit.
  final String? model;

  const ScreeningAnalysis({
    required this.summary,
    required this.analyzedAt,
    this.findings = const [],
    this.model,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'analyzed_at': analyzedAt.toUtc().toIso8601String(),
        'model': model,
        'findings': findings.map((f) => f.toJson()).toList(),
      };

  factory ScreeningAnalysis.fromJson(Map<String, dynamic> json) =>
      ScreeningAnalysis(
        summary: json['summary'] as String? ?? '',
        analyzedAt: DateTime.parse(json['analyzed_at'] as String).toLocal(),
        model: json['model'] as String?,
        findings: ((json['findings'] as List<dynamic>?) ?? const [])
            .map((e) => ScreeningFinding.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One AI-reported observation, optionally tied to a region or tooth.
class ScreeningFinding {
  final String label;
  final String? detail;
  final String? regionId;

  /// Tooth identifier if the service reports one (e.g. FDI "26").
  final String? tooth;

  /// 0–1, only when the service reports it. Never estimated by the app.
  final double? confidence;

  const ScreeningFinding({
    required this.label,
    this.detail,
    this.regionId,
    this.tooth,
    this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'detail': detail,
        'region_id': regionId,
        'tooth': tooth,
        'confidence': confidence,
      };

  factory ScreeningFinding.fromJson(Map<String, dynamic> json) =>
      ScreeningFinding(
        label: json['label'] as String,
        detail: json['detail'] as String?,
        regionId: json['region_id'] as String?,
        tooth: json['tooth'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
      );
}

/// User-reported context attached to a screening: a snapshot of the
/// relevant dental profile answers when the session was first saved.
///
/// This is the user's own account, not something the model detected, and
/// it is never sent to the image model. Reported symptoms don't confirm a
/// finding, and no reported symptoms doesn't mean healthy teeth.
class ScreeningReportedContext {
  const ScreeningReportedContext({
    required this.profileVersion,
    required this.recordedAt,
    this.currentConcerns = const {},
    this.concernDuration,
    this.discomfortLevel,
    this.screeningGoals = const {},
    this.difficultAreas = const {},
    this.dentalAppliances = const {},
  });

  /// Dental profile version the snapshot was taken from.
  final int profileVersion;
  final DateTime recordedAt;
  final Set<CurrentConcern> currentConcerns;
  final ConcernDuration? concernDuration;
  final DiscomfortLevel? discomfortLevel;
  final Set<ScreeningGoal> screeningGoals;
  final Set<DifficultArea> difficultAreas;
  final Set<DentalAppliance> dentalAppliances;

  /// Read through [DentalAnswers] so ids are parsed in one place.
  factory ScreeningReportedContext.fromJson(Map<String, dynamic> json) {
    final a = DentalAnswers.fromJson(json);
    return ScreeningReportedContext(
      profileVersion: json['profile_version'] as int? ?? 1,
      recordedAt: DateTime.parse(json['recorded_at'] as String).toLocal(),
      currentConcerns: a.currentConcerns,
      concernDuration: a.concernDuration,
      discomfortLevel: a.discomfortLevel,
      screeningGoals: a.screeningGoals,
      difficultAreas: a.difficultAreas,
      dentalAppliances: a.dentalAppliances,
    );
  }

  Map<String, dynamic> toJson() => {
        'source': 'user_reported',
        'profile_version': profileVersion,
        'current_concerns': [for (final c in currentConcerns) c.id],
        'concern_duration': concernDuration?.id,
        'discomfort_level': discomfortLevel?.id,
        'screening_goals': [for (final g in screeningGoals) g.id],
        'difficult_areas': [for (final d in difficultAreas) d.id],
        'dental_appliances': [for (final d in dentalAppliances) d.id],
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };
}
