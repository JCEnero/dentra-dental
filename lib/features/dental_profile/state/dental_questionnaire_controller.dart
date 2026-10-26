import 'package:flutter/foundation.dart';

import '../data/dental_profile_repository.dart';
import '../data/dental_questions.dart';
import '../data/models/dental_answers.dart';
import '../data/questionnaire_draft_store.dart';

/// Form state for the dental questionnaire: answers, the current step,
/// validation errors and submission.
///
/// Answers live here, not in the step widgets, so moving between steps
/// never loses them. In onboarding, every change is also written to a
/// [QuestionnaireDraftStore] so an unfinished questionnaire resumes later.
class DentalQuestionnaireController extends ChangeNotifier {
  DentalQuestionnaireController({
    required DentalAnswers initial,
    int initialStep = 0,
    this.draftStore,
    this.draftOwner,
  })  : _answers = initial,
        _saved = initial.normalized(),
        _step = initialStep.clamp(0, reviewStep),
        // Opening on review (editing a saved profile) means section edits
        // come back to review.
        _returnToReview = initialStep >= reviewStep;

  /// Index of the review page, after the last question step.
  static int get reviewStep => dentalSteps.length;

  /// Shown when a save fails without a message of its own.
  static const genericSaveError =
      "Your answers weren't saved. Please try again.";

  final QuestionnaireDraftStore? draftStore;

  /// User id the draft belongs to.
  final String? draftOwner;

  DentalAnswers _answers;
  final DentalAnswers _saved;
  int _step;
  bool _returnToReview;
  Map<DentalQuestionId, String> _errors = const {};
  bool _submitting = false;
  String? _submitError;
  bool _disposed = false;

  /// Draft writes run one after another, in order.
  Future<void> _draftWrites = Future.value();

  DentalAnswers get answers => _answers;
  int get step => _step;
  bool get onReview => _step == reviewStep;
  DentalStep? get currentStep => onReview ? null : dentalSteps[_step];

  /// Messages for unanswered or invalid questions on the current step,
  /// set when Continue is pressed.
  Map<DentalQuestionId, String> get errors => _errors;
  bool get submitting => _submitting;
  String? get submitError => _submitError;

  /// Whether Continue leads back to review (after "Edit" from review).
  bool get returnsToReview => _returnToReview;

  /// The answers differ from what was loaded (or saved).
  bool get isDirty => _answers.normalized() != _saved;

  /// An optional step with nothing entered can be skipped.
  bool get canSkip {
    final step = currentStep;
    if (step == null || !step.optional) return false;
    return step.questions.every((q) =>
        _answers.selectedFor(q).isEmpty && _answers.detailFor(q).trim().isEmpty);
  }

  // ── Answers ───────────────────────────────────────────────────

  void toggle(DentalQuestionId q, AnswerOption option) {
    if (_submitting) return;
    _answers = _answers.toggle(q, option);
    _clearError(q);
    _changed();
  }

  void setDetail(DentalQuestionId q, String text) {
    if (_submitting || _answers.detailFor(q) == text) return;
    _answers = _answers.withDetail(q, text);
    _clearError(q);
    _changed();
  }

  void _clearError(DentalQuestionId q) {
    _submitError = null;
    if (_errors.containsKey(q)) _errors = {..._errors}..remove(q);
  }

  // ── Navigation ────────────────────────────────────────────────

  /// Moves on if the current step is complete. Otherwise sets [errors]
  /// and returns false.
  bool next() {
    final step = currentStep;
    if (step == null || _submitting) return false;
    final errors = {..._answers.missingIn(step), ..._answers.tooLongIn(step)};
    if (errors.isNotEmpty) {
      _errors = errors;
      _notify();
      return false;
    }
    _goTo(_returnToReview ? reviewStep : _step + 1);
    return true;
  }

  void skip() {
    if (!canSkip || _submitting) return;
    _goTo(_returnToReview ? reviewStep : _step + 1);
  }

  void back() {
    if (_step == 0 || _submitting) return;
    _goTo(_step - 1);
  }

  /// Opens [stepIndex] from review; Continue then returns to review.
  void edit(int stepIndex) {
    if (_submitting) return;
    _returnToReview = true;
    _goTo(stepIndex);
  }

  void _goTo(int step) {
    _step = step.clamp(0, reviewStep);
    _errors = const {};
    _submitError = null;
    _changed();
  }

  // ── Submit ────────────────────────────────────────────────────

  /// Sends the normalized answers with [save] and returns true only once
  /// it completes. Ignored while a submission is already running, so a
  /// double tap can't send twice. On failure the answers stay as they are
  /// and [submitError] explains what happened.
  Future<bool> submit(Future<void> Function(DentalAnswers answers) save) async {
    if (_submitting || !onReview) return false;

    final incomplete =
        dentalSteps.indexWhere((s) => _answers.missingIn(s).isNotEmpty ||
            _answers.tooLongIn(s).isNotEmpty);
    if (incomplete != -1) {
      // Shouldn't happen through the UI; send the user to fix it.
      _returnToReview = true;
      _goTo(incomplete);
      next();
      return false;
    }

    _submitting = true;
    _submitError = null;
    _notify();

    // A draft write still in flight must not land after the save clears
    // the draft.
    await _draftWrites;
    try {
      await save(_answers.normalized());
      _submitting = false;
      _notify();
      return true;
    } on DentalProfileException catch (e) {
      _submitError = e.message;
    } catch (_) {
      _submitError = genericSaveError;
    }
    _submitting = false;
    _notify();
    return false;
  }

  // ── Internals ─────────────────────────────────────────────────

  void _changed() {
    _saveDraft();
    _notify();
  }

  void _saveDraft() {
    final store = draftStore;
    final owner = draftOwner;
    if (store == null || owner == null) return;
    final draft = QuestionnaireDraft(answers: _answers, step: _step);
    _draftWrites = _draftWrites
        .then((_) => store.write(owner, draft))
        // A failed write only loses the resume point; keep the chain going.
        .catchError((Object _) {});
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
