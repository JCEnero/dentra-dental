import '../../../dental_profile/data/models/dental_answers.dart';
import '../../../scan/data/scan_outcomes.dart';

/// Answers to the short check-in before a scan.
///
/// Like the dental profile, everything here is the user's own account. It
/// shapes the advice shown with a result, keeps its source wherever it's shown,
/// and is never sent to the image model. Ids match the backend's
/// `screening.schemas.ts` and the `screening_check_ins` CHECK constraints.

T? _byId<T extends AnswerOption>(List<T> values, Object? id) {
  for (final v in values) {
    if (v.id == id) return v;
  }
  return null;
}

Set<T> _setFrom<T extends AnswerOption>(List<T> values, Object? json) => {
      if (json is List)
        for (final id in json)
          if (_byId(values, id) case final option?) option,
    };

List<String> _teeth(Object? json) =>
    json is List ? json.whereType<String>().toList() : const [];

/// Where something is, in the same six general areas the results use.
enum AreaAnswer implements AnswerOption {
  upperRight(MouthArea.upperRight),
  upperFront(MouthArea.upperFront),
  upperLeft(MouthArea.upperLeft),
  lowerRight(MouthArea.lowerRight),
  lowerFront(MouthArea.lowerFront),
  lowerLeft(MouthArea.lowerLeft),
  notSure(null);

  const AreaAnswer(this.area);

  /// Null for "not sure".
  final MouthArea? area;

  @override
  String get id => area?.id ?? 'not_sure';
  @override
  String get label => area?.label ?? 'Not sure';
  @override
  bool get exclusive => false;
}

enum SymptomPattern implements AnswerOption {
  occasional('occasional', 'Comes and goes'),
  persistent('persistent', 'Constant'),
  worsening('worsening', 'Getting worse');

  const SymptomPattern(this.id, this.label);
  @override
  final String id;
  @override
  final String label;
  @override
  bool get exclusive => false;
}

/// Signs that change how soon someone needs care, from NHS guidance on
/// toothache and dental abscesses.
enum WarningSign implements AnswerOption {
  hardToBreathe(
    'hard_to_breathe',
    'Hard to breathe, swallow or speak',
    'trouble breathing, swallowing or speaking',
    emergency: true,
  ),
  eyeOrNeckSwelling(
    'eye_or_neck_swelling',
    'Swelling near my eye or in my neck',
    'swelling near your eye or in your neck',
    emergency: true,
  ),
  hardToOpenMouth(
    'hard_to_open_mouth',
    'Hard to open my mouth',
    'trouble opening your mouth',
    emergency: true,
  ),
  cheekOrJawSwelling(
    'cheek_or_jaw_swelling',
    'Swollen cheek or jaw',
    'a swollen cheek or jaw',
  ),
  fever('fever', 'A high temperature', 'a high temperature'),
  none('none', 'None of these', '', exclusive: true);

  const WarningSign(
    this.id,
    this.label,
    this.inWords, {
    this.emergency = false,
    this.exclusive = false,
  });
  @override
  final String id;
  @override
  final String label;

  /// How it reads in a sentence to the user.
  final String inWords;

  /// Needs emergency care rather than a dental appointment.
  final bool emergency;
  @override
  final bool exclusive;
}

enum RecentTreatment implements AnswerOption {
  filling('filling', 'Filling', 'a filling'),
  extraction('extraction', 'Tooth removed', 'a tooth removed'),
  rootCanal('root_canal', 'Root canal', 'a root canal'),
  crown('crown', 'Crown or bridge', 'a crown or bridge'),
  cleaning('cleaning', 'Cleaning', 'a cleaning'),
  other('other', 'Something else', 'dental treatment'),
  none('none', 'None', '', exclusive: true);

  const RecentTreatment(
    this.id,
    this.label,
    this.inWords, {
    this.exclusive = false,
  });
  @override
  final String id;
  @override
  final String label;

  /// How it reads in a sentence to the user.
  final String inWords;
  @override
  final bool exclusive;

  /// Work on a tooth that can look like a mark in a photo, or a healing site.
  bool get changesTheLook =>
      this == filling ||
      this == crown ||
      this == extraction ||
      this == rootCanal;
}

enum TreatmentWhen implements AnswerOption {
  pastWeek('past_week', 'Past week', 'in the past week', recent: true),
  pastMonth('past_month', 'Past month', 'in the past month', recent: true),
  past3Months(
    'past_3_months',
    'Past 3 months',
    'in the past 3 months',
    recent: true,
  ),
  longer('longer', 'Longer ago', 'more than 3 months ago'),
  notSure('not_sure', 'Not sure', '');

  const TreatmentWhen(
    this.id,
    this.label,
    this.inWords, {
    this.recent = false,
  });
  @override
  final String id;
  @override
  final String label;

  /// How it reads in a sentence. Empty when the user wasn't sure.
  final String inWords;
  final bool recent;
  @override
  bool get exclusive => false;
}

/// When a symptom started. The profile's "comes and goes" answer is a pattern
/// here, so it isn't offered.
const List<ConcernDuration> symptomStarts = [
  ConcernDuration.today,
  ConcernDuration.fewDays,
  ConcernDuration.fewWeeks,
  ConcernDuration.monthOrLonger,
  ConcernDuration.notSure,
];

/// The concerns the check-in asks about. Spots and discoloration are left to
/// the photos, and "not sure" to skipping the question.
const List<CurrentConcern> checkInSymptoms = [
  CurrentConcern.toothPain,
  CurrentConcern.sensitivity,
  CurrentConcern.bleedingGums,
  CurrentConcern.swollenGums,
  CurrentConcern.brokenTooth,
  CurrentConcern.other,
];

class ScanCheckIn {
  const ScanCheckIn({
    this.symptoms = const {},
    this.symptomArea,
    this.symptomTeeth = const [],
    this.started,
    this.pattern,
    this.severity,
    this.warningSigns = const {},
    this.lastCheckup,
    this.lastCleaning,
    this.treatments = const {},
    this.treatmentTeeth = const [],
    this.treatmentWhen,
    this.focusArea,
    this.focusTeeth = const [],
    this.recordedAt,
  });

  /// Empty when the question was skipped; {none} when nothing's wrong.
  final Set<CurrentConcern> symptoms;
  final AreaAnswer? symptomArea;

  /// FDI numbers, only when the user knows them.
  final List<String> symptomTeeth;
  final ConcernDuration? started;
  final SymptomPattern? pattern;
  final DiscomfortLevel? severity;
  final Set<WarningSign> warningSigns;
  final LastCheckup? lastCheckup;
  final LastCleaning? lastCleaning;

  /// Since the last scan, or lately on a first scan. {none} when there was none.
  final Set<RecentTreatment> treatments;
  final List<String> treatmentTeeth;
  final TreatmentWhen? treatmentWhen;

  /// A tooth or area the user wants noted, whether or not it hurts.
  final AreaAnswer? focusArea;
  final List<String> focusTeeth;

  /// Set by the server when saved.
  final DateTime? recordedAt;

  /// An actual symptom, so its follow-ups are asked.
  bool get hasSymptom => symptoms.any((s) => s.isActive);

  bool get asksSeverity => symptoms.any((s) => s.mayHurt);

  /// Swelling, or pain that's bad or getting worse, could be spreading.
  bool get asksWarningSigns =>
      symptoms.contains(CurrentConcern.swollenGums) ||
      (symptoms.contains(CurrentConcern.toothPain) &&
          (severity == DiscomfortLevel.severe ||
              pattern == SymptomPattern.worsening));

  bool get hasTreatment => treatments.any((t) => !t.exclusive);

  bool get needsEmergencyCare => warningSigns.any((w) => w.emergency);

  /// Nothing was answered, so there's nothing to store.
  bool get isEmpty {
    final a = normalized();
    return a.symptoms.isEmpty &&
        a.lastCheckup == null &&
        a.lastCleaning == null &&
        a.treatments.isEmpty &&
        a.focusArea == null &&
        a.focusTeeth.isEmpty;
  }

  /// Drops answers to follow-ups that aren't showing, e.g. after a symptom was
  /// unticked. This is what is saved.
  ScanCheckIn normalized() => ScanCheckIn(
        symptoms: symptoms,
        symptomArea: hasSymptom ? symptomArea : null,
        symptomTeeth: hasSymptom ? symptomTeeth : const [],
        started: hasSymptom ? started : null,
        pattern: hasSymptom ? pattern : null,
        severity: asksSeverity ? severity : null,
        warningSigns: hasSymptom && asksWarningSigns ? warningSigns : const {},
        lastCheckup: lastCheckup,
        lastCleaning: lastCleaning,
        treatments: treatments,
        treatmentTeeth: hasTreatment ? treatmentTeeth : const [],
        treatmentWhen: hasTreatment ? treatmentWhen : null,
        focusArea: focusArea,
        focusTeeth: focusTeeth,
        recordedAt: recordedAt,
      );

  ScanCheckIn copyWith({
    Set<CurrentConcern>? symptoms,
    AreaAnswer? symptomArea,
    List<String>? symptomTeeth,
    ConcernDuration? started,
    SymptomPattern? pattern,
    DiscomfortLevel? severity,
    Set<WarningSign>? warningSigns,
    LastCheckup? lastCheckup,
    LastCleaning? lastCleaning,
    Set<RecentTreatment>? treatments,
    List<String>? treatmentTeeth,
    TreatmentWhen? treatmentWhen,
    AreaAnswer? focusArea,
    List<String>? focusTeeth,
  }) =>
      ScanCheckIn(
        symptoms: symptoms ?? this.symptoms,
        symptomArea: symptomArea ?? this.symptomArea,
        symptomTeeth: symptomTeeth ?? this.symptomTeeth,
        started: started ?? this.started,
        pattern: pattern ?? this.pattern,
        severity: severity ?? this.severity,
        warningSigns: warningSigns ?? this.warningSigns,
        lastCheckup: lastCheckup ?? this.lastCheckup,
        lastCleaning: lastCleaning ?? this.lastCleaning,
        treatments: treatments ?? this.treatments,
        treatmentTeeth: treatmentTeeth ?? this.treatmentTeeth,
        treatmentWhen: treatmentWhen ?? this.treatmentWhen,
        focusArea: focusArea ?? this.focusArea,
        focusTeeth: focusTeeth ?? this.focusTeeth,
        recordedAt: recordedAt,
      );

  /// The API's body (normalized). Read-only keys are ignored there.
  Map<String, dynamic> toJson() {
    final a = normalized();
    List<String> ids(Set<AnswerOption> s) => [for (final o in s) o.id];
    return {
      'source': 'user_reported',
      'symptoms': ids(a.symptoms),
      'symptom_area': a.symptomArea?.id,
      'symptom_teeth': a.symptomTeeth,
      'symptom_started': a.started?.id,
      'symptom_pattern': a.pattern?.id,
      'symptom_severity': a.severity?.id,
      'warning_signs': ids(a.warningSigns),
      'last_checkup': a.lastCheckup?.id,
      'last_cleaning': a.lastCleaning?.id,
      'treatments': ids(a.treatments),
      'treatment_teeth': a.treatmentTeeth,
      'treatment_when': a.treatmentWhen?.id,
      'focus_area': a.focusArea?.id,
      'focus_teeth': a.focusTeeth,
      'recorded_at': a.recordedAt?.toUtc().toIso8601String(),
    };
  }

  /// Reads API responses. Unknown ids are ignored.
  factory ScanCheckIn.fromJson(Map<String, dynamic> json) => ScanCheckIn(
        symptoms: _setFrom(CurrentConcern.values, json['symptoms']),
        symptomArea: _byId(AreaAnswer.values, json['symptom_area']),
        symptomTeeth: _teeth(json['symptom_teeth']),
        started: _byId(ConcernDuration.values, json['symptom_started']),
        pattern: _byId(SymptomPattern.values, json['symptom_pattern']),
        severity: _byId(DiscomfortLevel.values, json['symptom_severity']),
        warningSigns: _setFrom(WarningSign.values, json['warning_signs']),
        lastCheckup: _byId(LastCheckup.values, json['last_checkup']),
        lastCleaning: _byId(LastCleaning.values, json['last_cleaning']),
        treatments: _setFrom(RecentTreatment.values, json['treatments']),
        treatmentTeeth: _teeth(json['treatment_teeth']),
        treatmentWhen: _byId(TreatmentWhen.values, json['treatment_when']),
        focusArea: _byId(AreaAnswer.values, json['focus_area']),
        focusTeeth: _teeth(json['focus_teeth']),
        recordedAt: switch (json['recorded_at']) {
          final String at => DateTime.tryParse(at)?.toLocal(),
          _ => null,
        },
      );
}
