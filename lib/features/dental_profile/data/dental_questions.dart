import 'models/dental_answers.dart';

/// Every question in the dental onboarding questionnaire.
enum DentalQuestionId {
  lastCheckup,
  previousProblems,
  currentConcerns,
  concernDuration,
  discomfortLevel,
  screeningGoals,
  difficultAreas,
  pastTreatments,
  lastCleaning,
  brushing,
  betweenTeeth,
  healthFactors,
  dentalAppliances,
  additionalInformation,
}

/// A free-text box shown under a question, e.g. when "Other" is chosen.
class DentalDetailField {
  const DentalDetailField({
    required this.label,
    required this.hint,
    this.maxLength = DentalTextLimits.detail,
    this.multiline = false,
  });

  final String label;
  final String hint;
  final int maxLength;
  final bool multiline;
}

/// What a question asks and how it is answered. The answer itself lives
/// in [DentalAnswers]; see [DentalAnswersAccess].
class DentalQuestion {
  const DentalQuestion({
    required this.id,
    required this.title,
    required this.reviewLabel,
    this.options = const [],
    this.multiple = false,
    this.optional = false,
    this.helper,
    this.detail,
  });

  final DentalQuestionId id;
  final String title;

  /// Short label for the review screen.
  final String reviewLabel;

  /// Empty for a text-only question.
  final List<AnswerOption> options;
  final bool multiple;
  final bool optional;
  final String? helper;
  final DentalDetailField? detail;

  bool get textOnly => options.isEmpty;
}

/// One slide of the questionnaire: a single question, or a few closely
/// related ones.
class DentalStep {
  const DentalStep({
    required this.eyebrow,
    required this.questions,
    this.title,
    this.summary,
    this.optional = false,
  });

  /// Short section name shown above the heading and read with progress.
  final String eyebrow;
  final List<DentalQuestionId> questions;

  /// Heading for a slide with several questions. A single-question slide
  /// uses the question itself as its heading.
  final String? title;
  final String? summary;

  /// The whole step may be skipped.
  final bool optional;

  bool get singleQuestion => questions.length == 1;
}

const _selectAll = 'Select all that apply.';

Set<AnswerOption> _one(AnswerOption? option) =>
    option == null ? const {} : {option};

const Map<DentalQuestionId, DentalQuestion> dentalQuestions = {
  DentalQuestionId.lastCheckup: DentalQuestion(
    id: DentalQuestionId.lastCheckup,
    title: 'When was your last dental checkup?',
    reviewLabel: 'Last dental checkup',
    options: LastCheckup.values,
  ),
  DentalQuestionId.previousProblems: DentalQuestion(
    id: DentalQuestionId.previousProblems,
    title: 'Have you had any dental problems before?',
    reviewLabel: 'Past dental problems',
    helper: _selectAll,
    options: PreviousProblem.values,
    multiple: true,
    detail: DentalDetailField(
      label: 'Other problem (optional)',
      hint: 'e.g. a root canal or an extraction',
    ),
  ),
  DentalQuestionId.currentConcerns: DentalQuestion(
    id: DentalQuestionId.currentConcerns,
    title: 'Are you having any dental or oral health concerns right now?',
    reviewLabel: 'Current concerns',
    helper: _selectAll,
    options: CurrentConcern.values,
    multiple: true,
    detail: DentalDetailField(
      label: 'Your concern (optional)',
      hint: 'Briefly describe what you notice',
    ),
  ),
  DentalQuestionId.concernDuration: DentalQuestion(
    id: DentalQuestionId.concernDuration,
    title: 'How long have you had this concern?',
    reviewLabel: 'How long',
    options: ConcernDuration.values,
  ),
  DentalQuestionId.discomfortLevel: DentalQuestion(
    id: DentalQuestionId.discomfortLevel,
    title: 'How would you describe your discomfort right now?',
    reviewLabel: 'Discomfort',
    helper: 'Your own description, not a clinical pain assessment.',
    options: DiscomfortLevel.values,
  ),
  DentalQuestionId.screeningGoals: DentalQuestion(
    id: DentalQuestionId.screeningGoals,
    title: 'What would you most like to check during your screening?',
    reviewLabel: 'Screening goals',
    helper: _selectAll,
    options: ScreeningGoal.values,
    multiple: true,
    detail: DentalDetailField(
      label: 'What would you like to check? (optional)',
      hint: 'e.g. a dark spot on an upper front tooth',
    ),
  ),
  DentalQuestionId.difficultAreas: DentalQuestion(
    id: DentalQuestionId.difficultAreas,
    title: 'Are any areas of your mouth hard for you to see or check?',
    reviewLabel: 'Hard-to-check areas',
    helper: 'This helps us tailor scan tips. It doesn’t mean anything '
        'is wrong there.',
    options: DifficultArea.values,
    multiple: true,
  ),
  DentalQuestionId.pastTreatments: DentalQuestion(
    id: DentalQuestionId.pastTreatments,
    title: 'Have you had any of these treatments?',
    reviewLabel: 'Past treatments',
    helper: 'Fillings and crowns can look like marks in a photo.',
    options: PastTreatment.values,
    multiple: true,
    optional: true,
  ),
  DentalQuestionId.lastCleaning: DentalQuestion(
    id: DentalQuestionId.lastCleaning,
    title: 'When was your last professional cleaning?',
    reviewLabel: 'Last cleaning',
    options: LastCleaning.values,
    optional: true,
  ),
  DentalQuestionId.brushing: DentalQuestion(
    id: DentalQuestionId.brushing,
    title: 'How often do you brush your teeth?',
    reviewLabel: 'Brushing',
    options: BrushingHabit.values,
    optional: true,
  ),
  DentalQuestionId.betweenTeeth: DentalQuestion(
    id: DentalQuestionId.betweenTeeth,
    title: 'How often do you clean between your teeth?',
    reviewLabel: 'Cleaning between teeth',
    helper: 'With floss or small brushes.',
    options: BetweenTeethHabit.values,
    optional: true,
  ),
  DentalQuestionId.healthFactors: DentalQuestion(
    id: DentalQuestionId.healthFactors,
    title: 'Do any of these apply to you?',
    reviewLabel: 'Health factors',
    helper: 'They can affect your teeth and gums.',
    options: HealthFactor.values,
    multiple: true,
    optional: true,
  ),
  DentalQuestionId.dentalAppliances: DentalQuestion(
    id: DentalQuestionId.dentalAppliances,
    title: 'Do you use any of these dental appliances?',
    reviewLabel: 'Dental appliances',
    helper: _selectAll,
    options: DentalAppliance.values,
    multiple: true,
    optional: true,
    detail: DentalDetailField(
      label: 'Other appliance (optional)',
      hint: 'e.g. a night guard',
    ),
  ),
  DentalQuestionId.additionalInformation: DentalQuestion(
    id: DentalQuestionId.additionalInformation,
    title: 'Is there anything else you’d like DENTRA to know?',
    reviewLabel: 'Anything else',
    optional: true,
    detail: DentalDetailField(
      label: 'Anything else (optional)',
      hint: 'Anything that may help when reviewing your screenings',
      maxLength: DentalTextLimits.additionalInformation,
      multiline: true,
    ),
  ),
};

/// The questionnaire, in order. Review comes after the last step.
const List<DentalStep> dentalSteps = [
  DentalStep(
    eyebrow: 'Dental background',
    questions: [DentalQuestionId.lastCheckup],
  ),
  DentalStep(
    eyebrow: 'Dental background',
    questions: [DentalQuestionId.previousProblems],
  ),
  DentalStep(
    eyebrow: 'Right now',
    title: 'How your mouth feels now',
    summary: 'Tell us about anything you’re noticing today.',
    questions: [
      DentalQuestionId.currentConcerns,
      DentalQuestionId.concernDuration,
      DentalQuestionId.discomfortLevel,
    ],
  ),
  DentalStep(
    eyebrow: 'Your screening',
    title: 'What to focus on',
    summary: 'This helps us organize your results and scan tips.',
    questions: [
      DentalQuestionId.screeningGoals,
      DentalQuestionId.difficultAreas,
    ],
  ),
  DentalStep(
    eyebrow: 'Optional',
    title: 'Your dental care',
    summary:
        'Skip this step if you prefer. It helps us fit your advice to you.',
    optional: true,
    questions: [
      DentalQuestionId.pastTreatments,
      DentalQuestionId.lastCleaning,
      DentalQuestionId.brushing,
      DentalQuestionId.betweenTeeth,
      DentalQuestionId.healthFactors,
    ],
  ),
  DentalStep(
    eyebrow: 'Optional',
    title: 'A few more details',
    summary: 'Skip this step if you prefer.',
    optional: true,
    questions: [
      DentalQuestionId.dentalAppliances,
      DentalQuestionId.additionalInformation,
    ],
  ),
];

/// Reads and writes answers by question, so the UI can stay generic.
extension DentalAnswersAccess on DentalAnswers {
  /// Whether [q] is shown, given the answers so far.
  bool shows(DentalQuestionId q) => switch (q) {
        DentalQuestionId.concernDuration => asksConcernDuration,
        DentalQuestionId.discomfortLevel => asksDiscomfort,
        _ => true,
      };

  Set<AnswerOption> selectedFor(DentalQuestionId q) => switch (q) {
        DentalQuestionId.lastCheckup => _one(lastCheckup),
        DentalQuestionId.previousProblems => previousProblems,
        DentalQuestionId.currentConcerns => currentConcerns,
        DentalQuestionId.concernDuration => _one(concernDuration),
        DentalQuestionId.discomfortLevel => _one(discomfortLevel),
        DentalQuestionId.screeningGoals => screeningGoals,
        DentalQuestionId.difficultAreas => difficultAreas,
        DentalQuestionId.pastTreatments => pastTreatments,
        DentalQuestionId.lastCleaning => _one(lastCleaning),
        DentalQuestionId.brushing => _one(brushing),
        DentalQuestionId.betweenTeeth => _one(betweenTeeth),
        DentalQuestionId.healthFactors => healthFactors,
        DentalQuestionId.dentalAppliances => dentalAppliances,
        DentalQuestionId.additionalInformation => const {},
      };

  /// Selects or deselects [option]. A single-choice question just takes
  /// it; in a multiple-choice one, exclusive answers ("None", "Not sure")
  /// clear everything else and are cleared by anything else.
  DentalAnswers toggle(DentalQuestionId q, AnswerOption option) {
    final question = dentalQuestions[q]!;
    final current = selectedFor(q);
    final Set<AnswerOption> next;
    if (!question.multiple) {
      next = {option};
    } else if (current.contains(option)) {
      next = {...current}..remove(option);
    } else if (option.exclusive) {
      next = {option};
    } else {
      next = {...current.where((o) => !o.exclusive), option};
    }
    return _withSelection(q, next);
  }

  DentalAnswers _withSelection(DentalQuestionId q, Set<AnswerOption> s) {
    Set<T> typed<T>() => s.cast<T>().toSet();
    return switch (q) {
      DentalQuestionId.lastCheckup =>
        copyWith(lastCheckup: s.firstOrNull as LastCheckup?),
      DentalQuestionId.previousProblems =>
        copyWith(previousProblems: typed<PreviousProblem>()),
      DentalQuestionId.currentConcerns =>
        copyWith(currentConcerns: typed<CurrentConcern>()),
      DentalQuestionId.concernDuration =>
        copyWith(concernDuration: s.firstOrNull as ConcernDuration?),
      DentalQuestionId.discomfortLevel =>
        copyWith(discomfortLevel: s.firstOrNull as DiscomfortLevel?),
      DentalQuestionId.screeningGoals =>
        copyWith(screeningGoals: typed<ScreeningGoal>()),
      DentalQuestionId.difficultAreas =>
        copyWith(difficultAreas: typed<DifficultArea>()),
      DentalQuestionId.pastTreatments =>
        copyWith(pastTreatments: typed<PastTreatment>()),
      DentalQuestionId.lastCleaning =>
        copyWith(lastCleaning: s.firstOrNull as LastCleaning?),
      DentalQuestionId.brushing =>
        copyWith(brushing: s.firstOrNull as BrushingHabit?),
      DentalQuestionId.betweenTeeth =>
        copyWith(betweenTeeth: s.firstOrNull as BetweenTeethHabit?),
      DentalQuestionId.healthFactors =>
        copyWith(healthFactors: typed<HealthFactor>()),
      DentalQuestionId.dentalAppliances =>
        copyWith(dentalAppliances: typed<DentalAppliance>()),
      DentalQuestionId.additionalInformation => this,
    };
  }

  /// Whether the question's detail box is shown.
  bool showsDetail(DentalQuestionId q) => switch (q) {
        DentalQuestionId.previousProblems => asksPreviousProblemsOther,
        DentalQuestionId.currentConcerns => asksCurrentConcernsOther,
        DentalQuestionId.screeningGoals => asksScreeningGoalsDetail,
        DentalQuestionId.dentalAppliances => asksDentalAppliancesOther,
        DentalQuestionId.additionalInformation => true,
        _ => false,
      };

  String detailFor(DentalQuestionId q) => switch (q) {
        DentalQuestionId.previousProblems => previousProblemsOther,
        DentalQuestionId.currentConcerns => currentConcernsOther,
        DentalQuestionId.screeningGoals => screeningGoalsDetail,
        DentalQuestionId.dentalAppliances => dentalAppliancesOther,
        DentalQuestionId.additionalInformation => additionalInformation,
        _ => '',
      };

  DentalAnswers withDetail(DentalQuestionId q, String text) => switch (q) {
        DentalQuestionId.previousProblems =>
          copyWith(previousProblemsOther: text),
        DentalQuestionId.currentConcerns =>
          copyWith(currentConcernsOther: text),
        DentalQuestionId.screeningGoals => copyWith(screeningGoalsDetail: text),
        DentalQuestionId.dentalAppliances =>
          copyWith(dentalAppliancesOther: text),
        DentalQuestionId.additionalInformation =>
          copyWith(additionalInformation: text),
        _ => this,
      };

  /// Shown, required questions in [step] that have no answer yet, with
  /// the message to show. Empty when the step can be completed.
  Map<DentalQuestionId, String> missingIn(DentalStep step) => {
        for (final q in step.questions)
          if (shows(q) &&
              !dentalQuestions[q]!.optional &&
              !dentalQuestions[q]!.textOnly &&
              selectedFor(q).isEmpty)
            q: dentalQuestions[q]!.multiple
                ? 'Choose at least one answer.'
                : 'Choose an answer.',
      };

  /// Detail text over its limit, by question.
  Map<DentalQuestionId, String> tooLongIn(DentalStep step) => {
        for (final q in step.questions)
          if (dentalQuestions[q]!.detail case final d?
              when showsDetail(q) && detailFor(q).trim().length > d.maxLength)
            q: 'Keep this under ${d.maxLength} characters.',
      };

  /// True when every required question in every step is answered.
  bool get isComplete =>
      dentalSteps.every((s) => missingIn(s).isEmpty && tooLongIn(s).isEmpty);
}
