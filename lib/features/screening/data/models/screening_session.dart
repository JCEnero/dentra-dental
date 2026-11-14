import '../../../dental_profile/data/models/dental_answers.dart';
import '../../../scan/data/scan_regions.dart';
import 'finding_answer.dart';
import 'scan_check_in.dart';

export 'finding_answer.dart';

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

  /// What the user said just before this scan, if they answered. Also
  /// self-reported, and also kept apart from [analysis].
  final ScanCheckIn? checkIn;

  /// What the user said about the teeth the check marked, one per finding they
  /// answered. Self-reported too: it shapes advice and never a finding.
  final List<FindingAnswer> findingAnswers;

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
    this.checkIn,
    this.findingAnswers = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// The answers by finding id.
  Map<String, ToothPain> get painByFinding => {
        for (final a in findingAnswers) a.findingId: a.pain,
      };

  /// Views with a photo. A view's second photo doesn't count again.
  int get capturedViewCount => capturedRegions.map(baseRegionId).toSet().length;

  bool get isComplete => capturedViewCount >= totalRegions;

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
    List<FindingAnswer>? findingAnswers,
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
      checkIn: checkIn,
      findingAnswers: findingAnswers ?? this.findingAnswers,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// This session with [pain] as the answer about [findingId], or with no
  /// answer about it when [pain] is null.
  ScreeningSession withAnswer(String findingId, ToothPain? pain) => copyWith(
        findingAnswers: [
          for (final a in findingAnswers)
            if (a.findingId != findingId) a,
          if (pain != null)
            FindingAnswer(
              findingId: findingId,
              pain: pain,
              answeredAt: DateTime.now(),
            ),
        ],
      );

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
        'check_in': checkIn?.toJson(),
        'finding_answers': [for (final a in findingAnswers) a.toJson()],
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
    final checkIn = json['check_in'];
    return ScreeningSession(
      id: json['id'] as String,
      userId: pick<String>('user_id', 'userId'),
      completedAt: date('completed_at', 'completedAt')!,
      capturedRegions:
          (pick<List<dynamic>>('captured_regions', 'capturedRegions') ??
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
      checkIn: checkIn == null
          ? null
          : ScanCheckIn.fromJson(checkIn as Map<String, dynamic>),
      findingAnswers: [
        for (final a in (json['finding_answers'] as List<dynamic>?) ?? const [])
          if (FindingAnswer.fromJson(a as Map<String, dynamic>)
              case final answer?)
            answer,
      ],
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

  /// The device's paired NIR frame, once stored. Null for phone photos.
  final String? nirImageUrl;

  /// Readings the device reported with the capture.
  final Map<String, Object>? deviceMeta;

  const ScreeningCapture({
    required this.regionId,
    required this.source,
    required this.capturedAt,
    this.imageUrl,
    this.nirImageUrl,
    this.deviceMeta,
  });

  Map<String, dynamic> toJson() => {
        'region_id': regionId,
        'source': source,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'image_url': imageUrl,
        'nir_image_url': nirImageUrl,
        'device_meta': deviceMeta,
      };

  factory ScreeningCapture.fromJson(Map<String, dynamic> json) =>
      ScreeningCapture(
        regionId: json['region_id'] as String,
        source: json['source'] as String? ?? 'phoneCamera',
        capturedAt: DateTime.parse(json['captured_at'] as String).toLocal(),
        imageUrl: json['image_url'] as String?,
        nirImageUrl: json['nir_image_url'] as String?,
        deviceMeta: (json['device_meta'] as Map<String, dynamic>?)
            ?.cast<String, Object>(),
      );
}

/// Server-side analysis progress. Analyses without one are [complete].
enum AnalysisStatus { pending, complete, retake, failed }

/// AI-assisted analysis of a session. Never a diagnosis.
class ScreeningAnalysis {
  /// Plain-language summary returned by the analysis service.
  final String summary;

  /// Structured findings, when the service provides them.
  final List<ScreeningFinding> findings;

  /// Findings below the line the rules act on: too unsure to advise anything,
  /// but worth showing and comparing on the next scan.
  final List<ScreeningFinding> faintFindings;

  /// Fillings and crowns the model saw. Not a concern, and never counted as a
  /// sign, but it tells someone their dental work was told apart from decay.
  final List<ScreeningFinding> dentalWork;
  final DateTime analyzedAt;

  /// Identifies the model/version that produced the result, for audit.
  final String? model;

  final AnalysisStatus status;

  /// 'primary', 'mixed', 'permanent' or 'unknown', when the service says.
  final String? dentitionType;

  /// What to do next, most urgent first.
  final List<ScreeningRecommendation> recommendations;

  /// Photos that couldn't be analyzed and should be taken again.
  final List<ScreeningQualityIssue> qualityIssues;

  /// How far a pending run has got. Never saved with the result.
  final ScreeningAnalysisProgress? progress;

  const ScreeningAnalysis({
    required this.summary,
    required this.analyzedAt,
    this.findings = const [],
    this.faintFindings = const [],
    this.dentalWork = const [],
    this.model,
    this.status = AnalysisStatus.complete,
    this.dentitionType,
    this.recommendations = const [],
    this.qualityIssues = const [],
    this.progress,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'analyzed_at': analyzedAt.toUtc().toIso8601String(),
        'model': model,
        'status': status.name,
        'dentition_type': dentitionType,
        'findings': findings.map((f) => f.toJson()).toList(),
        'faint_findings': faintFindings.map((f) => f.toJson()).toList(),
        'dental_work': dentalWork.map((f) => f.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'quality_issues': qualityIssues.map((q) => q.toJson()).toList(),
      };

  factory ScreeningAnalysis.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) from) =>
        ((json[key] as List<dynamic>?) ?? const [])
            .map((e) => from(e as Map<String, dynamic>))
            .toList();
    return ScreeningAnalysis(
      summary: json['summary'] as String? ?? '',
      analyzedAt: DateTime.parse(json['analyzed_at'] as String).toLocal(),
      model: json['model'] as String?,
      status: AnalysisStatus.values.asNameMap()[json['status']] ??
          AnalysisStatus.complete,
      dentitionType: json['dentition_type'] as String?,
      findings: list('findings', ScreeningFinding.fromJson),
      faintFindings: list('faint_findings', ScreeningFinding.fromJson),
      dentalWork: list('dental_work', ScreeningFinding.fromJson),
      recommendations:
          list('recommendations', ScreeningRecommendation.fromJson),
      qualityIssues: list('quality_issues', ScreeningQualityIssue.fromJson),
      progress: json['progress'] == null
          ? null
          : ScreeningAnalysisProgress.fromJson(
              json['progress'] as Map<String, dynamic>),
    );
  }
}

/// Where a running analysis is, as reported by the server after each photo.
class ScreeningAnalysisProgress {
  /// Photos finished, out of [total].
  final int done;
  final int total;

  const ScreeningAnalysisProgress({required this.done, required this.total});

  factory ScreeningAnalysisProgress.fromJson(Map<String, dynamic> json) =>
      ScreeningAnalysisProgress(
        done: json['done'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
      );
}

/// A next step from the analysis rules, e.g. "Possible cavity: see a
/// dentist". Screening advice, never a diagnosis.
class ScreeningRecommendation {
  /// Stable id, e.g. 'possible_filling', 'brushing_back_teeth'.
  final String code;
  final String title;
  final String detail;

  /// 'routine', 'soon' or 'prompt'.
  final String urgency;
  final List<String> regionIds;

  const ScreeningRecommendation({
    required this.code,
    required this.title,
    required this.detail,
    required this.urgency,
    this.regionIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'detail': detail,
        'urgency': urgency,
        'region_ids': regionIds,
      };

  factory ScreeningRecommendation.fromJson(Map<String, dynamic> json) =>
      ScreeningRecommendation(
        code: json['code'] as String,
        title: json['title'] as String,
        detail: json['detail'] as String? ?? '',
        urgency: json['urgency'] as String? ?? 'routine',
        regionIds:
            ((json['region_ids'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

/// A photo the quality check rejected (blurry, too dark, glare...).
class ScreeningQualityIssue {
  final String regionId;

  /// 'rgb' (the photo) or 'nir' (the device's light-scan frame).
  final String modality;
  final String reason;

  /// User-facing advice for the retake.
  final String message;

  const ScreeningQualityIssue({
    required this.regionId,
    required this.modality,
    required this.reason,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'region_id': regionId,
        'modality': modality,
        'reason': reason,
        'message': message,
      };

  factory ScreeningQualityIssue.fromJson(Map<String, dynamic> json) =>
      ScreeningQualityIssue(
        regionId: json['region_id'] as String,
        modality: json['modality'] as String? ?? 'rgb',
        reason: json['reason'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

/// One AI-reported observation, optionally tied to a region or tooth.
class ScreeningFinding {
  /// The server's id for it, which answers about it refer to. Null for results
  /// stored before ids were sent.
  final String? id;
  final String label;
  final String? detail;
  final String? regionId;

  /// Tooth identifier if the service reports one (e.g. FDI "26").
  final String? tooth;

  /// 0–1, only when the service reports it. Never estimated by the app.
  final double? confidence;

  /// Model category, e.g. 'enamel_caries', 'plaque'.
  final String? category;
  final String? severity;

  /// 'occlusal', 'buccal', 'lingual' or 'interproximal'.
  final String? surface;

  /// 'rgb' or 'nir': which image showed it.
  final String? modality;

  /// Where it is in the photo: [x, y, w, h], each 0-1. Null for older results.
  final List<double>? bbox;

  const ScreeningFinding({
    required this.label,
    this.id,
    this.detail,
    this.regionId,
    this.tooth,
    this.confidence,
    this.category,
    this.severity,
    this.surface,
    this.modality,
    this.bbox,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'detail': detail,
        'region_id': regionId,
        'tooth': tooth,
        'confidence': confidence,
        'category': category,
        'severity': severity,
        'surface': surface,
        'modality': modality,
        'bbox': bbox,
      };

  factory ScreeningFinding.fromJson(Map<String, dynamic> json) =>
      ScreeningFinding(
        id: switch (json['id']) {
          final String id => id,
          final int id => '$id',
          _ => null,
        },
        label: json['label'] as String,
        detail: json['detail'] as String?,
        regionId: json['region_id'] as String?,
        tooth: json['tooth'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        category: json['category'] as String?,
        severity: json['severity'] as String?,
        surface: json['surface'] as String?,
        modality: json['modality'] as String?,
        bbox: switch (json['bbox']) {
          final List<dynamic> b when b.length == 4 => [
              for (final v in b) (v as num).toDouble(),
            ],
          _ => null,
        },
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
    this.lastCheckup,
    this.previousProblems = const {},
    this.pastTreatments = const {},
    this.lastCleaning,
    this.brushing,
    this.betweenTeeth,
    this.healthFactors = const {},
    this.answeredAt,
  });

  /// The snapshot the server would take of [profile] right now, for a scan the
  /// server hasn't stored yet.
  factory ScreeningReportedContext.fromProfile(
    DentalProfile profile,
    DateTime at,
  ) {
    final a = profile.answers;
    return ScreeningReportedContext(
      profileVersion: profile.version,
      recordedAt: at,
      currentConcerns: a.currentConcerns,
      concernDuration: a.concernDuration,
      discomfortLevel: a.discomfortLevel,
      screeningGoals: a.screeningGoals,
      difficultAreas: a.difficultAreas,
      dentalAppliances: a.dentalAppliances,
      lastCheckup: a.lastCheckup,
      previousProblems: a.previousProblems,
      pastTreatments: a.pastTreatments,
      lastCleaning: a.lastCleaning,
      brushing: a.brushing,
      betweenTeeth: a.betweenTeeth,
      healthFactors: a.healthFactors,
      answeredAt: profile.updatedAt ?? profile.completedAt,
    );
  }

  /// Dental profile version the snapshot was taken from.
  final int profileVersion;
  final DateTime recordedAt;
  final Set<CurrentConcern> currentConcerns;
  final ConcernDuration? concernDuration;
  final DiscomfortLevel? discomfortLevel;
  final Set<ScreeningGoal> screeningGoals;
  final Set<DifficultArea> difficultAreas;
  final Set<DentalAppliance> dentalAppliances;
  final LastCheckup? lastCheckup;
  final Set<PreviousProblem> previousProblems;
  final Set<PastTreatment> pastTreatments;
  final LastCleaning? lastCleaning;
  final BrushingHabit? brushing;
  final BetweenTeethHabit? betweenTeeth;
  final Set<HealthFactor> healthFactors;

  /// When the user last changed these answers. Null on older snapshots.
  final DateTime? answeredAt;

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
      lastCheckup: a.lastCheckup,
      previousProblems: a.previousProblems,
      pastTreatments: a.pastTreatments,
      lastCleaning: a.lastCleaning,
      brushing: a.brushing,
      betweenTeeth: a.betweenTeeth,
      healthFactors: a.healthFactors,
      answeredAt: switch (json['answered_at']) {
        final String at => DateTime.tryParse(at)?.toLocal(),
        _ => null,
      },
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
        'last_checkup': lastCheckup?.id,
        'previous_problems': [for (final p in previousProblems) p.id],
        'past_treatments': [for (final t in pastTreatments) t.id],
        'last_cleaning': lastCleaning?.id,
        'brushing': brushing?.id,
        'between_teeth': betweenTeeth?.id,
        'health_factors': [for (final f in healthFactors) f.id],
        'answered_at': answeredAt?.toUtc().toIso8601String(),
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };
}
