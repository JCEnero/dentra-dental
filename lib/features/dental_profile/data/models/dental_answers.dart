/// Answers to the dental onboarding questionnaire.
///
/// Every answer is self-reported context for screenings. None of it is a
/// diagnosis, and none of it is ever sent to the image model: findings
/// come only from the photos.
///
/// Option [AnswerOption.id]s are the API's values and match the backend's
/// `dental-profile.schemas.ts` and the `dental_profiles` CHECK constraints.
library;

/// One selectable answer.
abstract interface class AnswerOption {
  /// Stable id sent to the API.
  String get id;

  /// What the user sees.
  String get label;

  /// Can't be combined with other answers ("None of these", "Not sure").
  bool get exclusive;
}

T? _byId<T extends AnswerOption>(List<T> values, Object? id) {
  for (final v in values) {
    if (v.id == id) return v;
  }
  return null;
}

/// Known ids from a JSON list, in order. Unknown ids (e.g. from a newer
/// app version's draft) are dropped instead of failing the whole load.
Set<T> _setFrom<T extends AnswerOption>(List<T> values, Object? json) => {
      if (json is List)
        for (final id in json)
          if (_byId(values, id) case final option?) option,
    };

enum LastCheckup implements AnswerOption {
  within6Months('within_6_months', 'Within the last 6 months'),
  sixTo12Months('6_to_12_months', '6–12 months ago'),
  overAYear('over_1_year', 'More than a year ago'),
  never('never', 'I have never had a dental checkup'),
  dontRemember('dont_remember', "I don't remember");

  const LastCheckup(this.id, this.label);
  @override
  final String id;
  @override
  final String label;
  @override
  bool get exclusive => false;
}

enum PreviousProblem implements AnswerOption {
  toothDecay('tooth_decay', 'Tooth decay or cavities'),
  gumProblems('gum_problems', 'Gum problems'),
  sensitivity('sensitivity', 'Tooth sensitivity'),
  toothPain('tooth_pain', 'Tooth pain'),
  brokenTooth('broken_tooth', 'Broken or chipped teeth'),
  other('other', 'Other'),
  none('none', 'None of these', exclusive: true),
  notSure('not_sure', 'Not sure', exclusive: true);

  const PreviousProblem(this.id, this.label, {this.exclusive = false});
  @override
  final String id;
  @override
  final String label;
  @override
  final bool exclusive;
}

enum CurrentConcern implements AnswerOption {
  none('none', 'No current concerns', exclusive: true),
  toothPain('tooth_pain', 'Tooth pain', mayHurt: true),
  sensitivity('sensitivity', 'Tooth sensitivity', mayHurt: true),
  bleedingGums('bleeding_gums', 'Bleeding gums', mayHurt: true),
  swollenGums('swollen_gums', 'Swollen gums', mayHurt: true),
  discoloration('discoloration', 'Visible spots or discoloration on teeth'),
  brokenTooth('broken_tooth', 'A chipped or broken tooth', mayHurt: true),
  other('other', 'Another concern', mayHurt: true),
  notSure('not_sure', "I'm not sure", exclusive: true);

  const CurrentConcern(
    this.id,
    this.label, {
    this.exclusive = false,
    this.mayHurt = false,
  });
  @override
  final String id;
  @override
  final String label;
  @override
  final bool exclusive;

  /// Asks how the discomfort feels when selected.
  final bool mayHurt;

  /// An actual concern, so "how long" is asked.
  bool get isActive => !exclusive;
}

enum ConcernDuration implements AnswerOption {
  today('today', 'It started today'),
  fewDays('few_days', 'A few days'),
  fewWeeks('few_weeks', 'A few weeks'),
  monthOrLonger('month_or_longer', 'A month or longer'),
  comesAndGoes('comes_and_goes', 'It comes and goes'),
  notSure('not_sure', "I'm not sure");

  const ConcernDuration(this.id, this.label);
  @override
  final String id;
  @override
  final String label;
  @override
  bool get exclusive => false;
}

enum DiscomfortLevel implements AnswerOption {
  none('none', 'No discomfort'),
  mild('mild', 'Mild'),
  moderate('moderate', 'Moderate'),
  severe('severe', 'Severe');

  const DiscomfortLevel(this.id, this.label);
  @override
  final String id;
  @override
  final String label;
  @override
  bool get exclusive => false;
}

enum ScreeningGoal implements AnswerOption {
  decay('decay', 'Possible tooth decay or cavities'),
  discoloration('discoloration', 'Tooth discoloration or unusual spots'),
  damage('damage', 'Visible tooth damage'),
  gumAppearance('gum_appearance', 'Gum appearance'),
  hardToSeeAreas(
      'hard_to_see_areas', 'Areas that are hard to see, such as back teeth'),
  generalMonitoring('general_monitoring', 'General oral health monitoring'),
  specificConcern('specific_concern', 'I have a specific concern'),
  other('other', 'Other');

  const ScreeningGoal(this.id, this.label);
  @override
  final String id;
  @override
  final String label;
  @override
  bool get exclusive => false;
}

enum DifficultArea implements AnswerOption {
  backTeeth('back_teeth', 'Back teeth or molars'),
  betweenTeeth('between_teeth', 'Spaces between teeth'),
  innerSurfaces('inner_surfaces', 'Inner surfaces of teeth'),
  backCorners('back_corners', 'Upper or lower back corners of my mouth'),
  noDifficulty('no_difficulty', 'No particular difficulty', exclusive: true),
  notSure('not_sure', "I'm not sure", exclusive: true);

  const DifficultArea(this.id, this.label, {this.exclusive = false});
  @override
  final String id;
  @override
  final String label;
  @override
  final bool exclusive;
}

enum DentalAppliance implements AnswerOption {
  braces('braces', 'Braces'),
  retainers('retainers', 'Retainers'),
  dentures('dentures', 'Dentures'),
  implants('implants', 'Dental implants'),
  crownsBridges('crowns_bridges', 'Dental crowns or bridges'),
  other('other', 'Other dental appliances'),
  none('none', 'None', exclusive: true),
  preferNotToAnswer('prefer_not_to_answer', 'Prefer not to answer',
      exclusive: true);

  const DentalAppliance(this.id, this.label, {this.exclusive = false});
  @override
  final String id;
  @override
  final String label;
  @override
  final bool exclusive;
}

/// Limits shared with the API.
abstract final class DentalTextLimits {
  static const int detail = 200;
  static const int additionalInformation = 500;
}

/// The questionnaire's answers, possibly incomplete while being filled in.
///
/// Answers to follow-up questions that are currently hidden are kept (so
/// toggling a concern off and on again restores them) but [normalized]
/// drops them before anything is shown for review or submitted.
class DentalAnswers {
  const DentalAnswers({
    this.lastCheckup,
    this.previousProblems = const {},
    this.previousProblemsOther = '',
    this.currentConcerns = const {},
    this.currentConcernsOther = '',
    this.concernDuration,
    this.discomfortLevel,
    this.screeningGoals = const {},
    this.screeningGoalsDetail = '',
    this.difficultAreas = const {},
    this.dentalAppliances = const {},
    this.dentalAppliancesOther = '',
    this.additionalInformation = '',
  });

  final LastCheckup? lastCheckup;
  final Set<PreviousProblem> previousProblems;
  final String previousProblemsOther;
  final Set<CurrentConcern> currentConcerns;
  final String currentConcernsOther;
  final ConcernDuration? concernDuration;
  final DiscomfortLevel? discomfortLevel;
  final Set<ScreeningGoal> screeningGoals;
  final String screeningGoalsDetail;
  final Set<DifficultArea> difficultAreas;
  final Set<DentalAppliance> dentalAppliances;
  final String dentalAppliancesOther;
  final String additionalInformation;

  /// "How long" is asked once an actual concern is reported.
  bool get asksConcernDuration => currentConcerns.any((c) => c.isActive);

  /// "How does it feel" is asked for concerns that may involve discomfort.
  bool get asksDiscomfort => currentConcerns.any((c) => c.mayHurt);

  /// Severe self-reported discomfort: the app advises prompt dental care,
  /// whatever any screening shows.
  bool get needsPromptCare =>
      asksDiscomfort && discomfortLevel == DiscomfortLevel.severe;

  bool get asksPreviousProblemsOther =>
      previousProblems.contains(PreviousProblem.other);
  bool get asksCurrentConcernsOther =>
      currentConcerns.contains(CurrentConcern.other);
  bool get asksScreeningGoalsDetail =>
      screeningGoals.contains(ScreeningGoal.specificConcern) ||
      screeningGoals.contains(ScreeningGoal.other);
  bool get asksDentalAppliancesOther =>
      dentalAppliances.contains(DentalAppliance.other);

  /// Drops answers to hidden questions and details whose option isn't
  /// selected, and trims text. This is what is reviewed and saved.
  DentalAnswers normalized() => DentalAnswers(
        lastCheckup: lastCheckup,
        previousProblems: previousProblems,
        previousProblemsOther:
            asksPreviousProblemsOther ? previousProblemsOther.trim() : '',
        currentConcerns: currentConcerns,
        currentConcernsOther:
            asksCurrentConcernsOther ? currentConcernsOther.trim() : '',
        concernDuration: asksConcernDuration ? concernDuration : null,
        discomfortLevel: asksDiscomfort ? discomfortLevel : null,
        screeningGoals: screeningGoals,
        screeningGoalsDetail:
            asksScreeningGoalsDetail ? screeningGoalsDetail.trim() : '',
        difficultAreas: difficultAreas,
        dentalAppliances: dentalAppliances,
        dentalAppliancesOther:
            asksDentalAppliancesOther ? dentalAppliancesOther.trim() : '',
        additionalInformation: additionalInformation.trim(),
      );

  DentalAnswers copyWith({
    LastCheckup? lastCheckup,
    Set<PreviousProblem>? previousProblems,
    String? previousProblemsOther,
    Set<CurrentConcern>? currentConcerns,
    String? currentConcernsOther,
    ConcernDuration? concernDuration,
    DiscomfortLevel? discomfortLevel,
    Set<ScreeningGoal>? screeningGoals,
    String? screeningGoalsDetail,
    Set<DifficultArea>? difficultAreas,
    Set<DentalAppliance>? dentalAppliances,
    String? dentalAppliancesOther,
    String? additionalInformation,
  }) {
    return DentalAnswers(
      lastCheckup: lastCheckup ?? this.lastCheckup,
      previousProblems: previousProblems ?? this.previousProblems,
      previousProblemsOther:
          previousProblemsOther ?? this.previousProblemsOther,
      currentConcerns: currentConcerns ?? this.currentConcerns,
      currentConcernsOther: currentConcernsOther ?? this.currentConcernsOther,
      concernDuration: concernDuration ?? this.concernDuration,
      discomfortLevel: discomfortLevel ?? this.discomfortLevel,
      screeningGoals: screeningGoals ?? this.screeningGoals,
      screeningGoalsDetail: screeningGoalsDetail ?? this.screeningGoalsDetail,
      difficultAreas: difficultAreas ?? this.difficultAreas,
      dentalAppliances: dentalAppliances ?? this.dentalAppliances,
      dentalAppliancesOther:
          dentalAppliancesOther ?? this.dentalAppliancesOther,
      additionalInformation:
          additionalInformation ?? this.additionalInformation,
    );
  }

  /// The API's request body (normalized; blank text becomes null).
  Map<String, dynamic> toJson() {
    final a = normalized();
    String? text(String v) => v.isEmpty ? null : v;
    List<String> ids(Set<AnswerOption> s) => [for (final o in s) o.id];
    return {
      'last_checkup': a.lastCheckup?.id,
      'previous_problems': ids(a.previousProblems),
      'previous_problems_other': text(a.previousProblemsOther),
      'current_concerns': ids(a.currentConcerns),
      'current_concerns_other': text(a.currentConcernsOther),
      'concern_duration': a.concernDuration?.id,
      'discomfort_level': a.discomfortLevel?.id,
      'screening_goals': ids(a.screeningGoals),
      'screening_goals_detail': text(a.screeningGoalsDetail),
      'difficult_areas': ids(a.difficultAreas),
      'dental_appliances': ids(a.dentalAppliances),
      'dental_appliances_other': text(a.dentalAppliancesOther),
      'additional_information': text(a.additionalInformation),
    };
  }

  /// Everything as entered, hidden follow-ups included. Used for drafts.
  Map<String, dynamic> toDraftJson() => {
        ...toJson(),
        'previous_problems_other': previousProblemsOther,
        'current_concerns_other': currentConcernsOther,
        'concern_duration': concernDuration?.id,
        'discomfort_level': discomfortLevel?.id,
        'screening_goals_detail': screeningGoalsDetail,
        'dental_appliances_other': dentalAppliancesOther,
        'additional_information': additionalInformation,
      };

  /// Reads API responses and drafts. Unknown ids are ignored.
  factory DentalAnswers.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key] as String? ?? '';
    return DentalAnswers(
      lastCheckup: _byId(LastCheckup.values, json['last_checkup']),
      previousProblems:
          _setFrom(PreviousProblem.values, json['previous_problems']),
      previousProblemsOther: text('previous_problems_other'),
      currentConcerns: _setFrom(CurrentConcern.values, json['current_concerns']),
      currentConcernsOther: text('current_concerns_other'),
      concernDuration: _byId(ConcernDuration.values, json['concern_duration']),
      discomfortLevel: _byId(DiscomfortLevel.values, json['discomfort_level']),
      screeningGoals: _setFrom(ScreeningGoal.values, json['screening_goals']),
      screeningGoalsDetail: text('screening_goals_detail'),
      difficultAreas: _setFrom(DifficultArea.values, json['difficult_areas']),
      dentalAppliances:
          _setFrom(DentalAppliance.values, json['dental_appliances']),
      dentalAppliancesOther: text('dental_appliances_other'),
      additionalInformation: text('additional_information'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DentalAnswers &&
      _mapEquals(other.toDraftJson(), toDraftJson());

  @override
  int get hashCode => Object.hashAllUnordered(
      toDraftJson().entries.map((e) => Object.hash(e.key, '${e.value}')));
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    final x = a[key];
    final y = b[key];
    if (x is List && y is List) {
      if (x.length != y.length || !x.toSet().containsAll(y)) return false;
    } else if (x != y) {
      return false;
    }
  }
  return true;
}

/// A saved dental profile, as returned by the API.
class DentalProfile {
  const DentalProfile({
    required this.answers,
    required this.version,
    required this.completedAt,
    this.updatedAt,
  });

  final DentalAnswers answers;

  /// Increases with every saved change.
  final int version;
  final DateTime completedAt;
  final DateTime? updatedAt;

  factory DentalProfile.fromJson(Map<String, dynamic> json) => DentalProfile(
        answers: DentalAnswers.fromJson(json),
        version: json['version'] as int? ?? 1,
        completedAt: DateTime.parse(json['completed_at'] as String).toLocal(),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        ...answers.toJson(),
        'version': version,
        'completed_at': completedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };
}
