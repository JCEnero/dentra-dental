import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/dental_questions.dart';
import '../data/models/dental_answers.dart';
import '../providers/dental_profile_providers.dart';
import '../state/dental_questionnaire_controller.dart';
import '../widgets/prompt_care_note.dart';
import '../widgets/question_block.dart';
import '../widgets/questionnaire_review.dart';
import '../widgets/welcome_illustration.dart';

enum QuestionnaireMode { onboarding, edit }

/// The dental profile questionnaire.
///
/// [QuestionnaireMode.onboarding]: shown by `DentalOnboardingGate` until a
/// profile is saved. A fresh start opens on a short welcome; a draft
/// resumes on the slide it was left on. Saving hands over to the app (the
/// gate switches once the server confirms).
///
/// [QuestionnaireMode.edit]: opened from Profile with the saved answers,
/// starting on review. Pops with `true` after a successful save.
class DentalQuestionnaireScreen extends ConsumerStatefulWidget {
  const DentalQuestionnaireScreen.onboarding({super.key})
      : mode = QuestionnaireMode.onboarding,
        profile = null;

  const DentalQuestionnaireScreen.edit({super.key, required this.profile})
      : mode = QuestionnaireMode.edit;

  final QuestionnaireMode mode;
  final DentalProfile? profile;

  static Route<bool> editRoute(DentalProfile profile) =>
      MaterialPageRoute<bool>(
        builder: (_) => DentalQuestionnaireScreen.edit(profile: profile),
      );

  @override
  ConsumerState<DentalQuestionnaireScreen> createState() =>
      _DentalQuestionnaireScreenState();
}

class _DentalQuestionnaireScreenState
    extends ConsumerState<DentalQuestionnaireScreen> {
  static const _maxWidth = 520.0;
  static const _gutter = 24.0;

  DentalQuestionnaireController? _controller;
  final _textControllers = <DentalQuestionId, TextEditingController>{};
  final _questionKeys = {
    for (final q in DentalQuestionId.values) q: GlobalKey(),
  };

  /// The welcome slide, before the first question of a fresh start.
  bool _welcome = false;

  /// Slide direction for the transition: 1 forward, -1 back.
  int _direction = 1;
  int _lastStep = 0;

  bool get _onboarding => widget.mode == QuestionnaireMode.onboarding;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    if (profile != null) {
      _attach(DentalQuestionnaireController(
        initial: profile.answers,
        initialStep: DentalQuestionnaireController.reviewStep,
      ));
    } else {
      _resumeDraft();
    }
  }

  /// Picks up where an unfinished onboarding was left, if anywhere.
  Future<void> _resumeDraft() async {
    final userId = ref.read(authServiceProvider).currentUserId;
    final store = ref.read(questionnaireDraftStoreProvider);
    final draft = userId == null ? null : await store.read(userId);
    if (!mounted) return;
    setState(() {
      _welcome = draft == null;
      _attach(DentalQuestionnaireController(
        initial: draft?.answers ?? const DentalAnswers(),
        initialStep: draft?.step ?? 0,
        draftStore: store,
        draftOwner: userId,
      ));
    });
  }

  void _attach(DentalQuestionnaireController controller) {
    _controller = controller;
    _lastStep = controller.step;
    controller.addListener(_trackDirection);
  }

  void _trackDirection() {
    final step = _controller!.step;
    if (step != _lastStep) {
      _direction = step > _lastStep ? 1 : -1;
      _lastStep = step;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _textFor(DentalQuestionId q) =>
      _textControllers.putIfAbsent(
        q,
        () => TextEditingController(text: _controller!.answers.detailFor(q)),
      );

  // ── Actions ───────────────────────────────────────────────────

  void _start() => setState(() {
        _direction = 1;
        _welcome = false;
      });

  void _continue() {
    final controller = _controller!;
    if (controller.next()) return;
    // Bring the first unanswered question into view; its error is a
    // live region, so screen readers announce it.
    final first = controller.currentStep!.questions
        .where(controller.errors.containsKey)
        .firstOrNull;
    final target = first == null ? null : _questionKeys[first]!.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: dentraMotion(context, 300),
        alignment: 0.1,
      );
    }
  }

  void _back() {
    final controller = _controller!;
    if (_onboarding && controller.step == 0 && !controller.returnsToReview) {
      setState(() {
        _direction = -1;
        _welcome = true;
      });
      return;
    }
    controller.back();
  }

  Future<void> _submit() async {
    final controller = _controller!;
    final toast = DentraToast.of(context);
    final navigator = Navigator.of(context);
    final ok = await controller.submit((answers) => ref
        .read(dentalProfileProvider.notifier)
        .save(answers, update: !_onboarding));
    if (!ok) return;

    if (_onboarding) {
      // The gate already shows the app; this screen may be gone.
      toast.show('Your dental profile is saved.');
    } else if (mounted) {
      navigator.pop(true);
    }
  }

  /// Onboarding: leave without finishing. The draft stays on this device,
  /// so the questionnaire resumes after signing back in.
  Future<void> _signOut() async {
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.logout_rounded,
      title: 'Sign out?',
      message: 'Your answers so far are kept on this device, so you can '
          'finish your dental profile next time you sign in.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !mounted) return;
    await ref.read(authServiceProvider).signOut();
  }

  /// Edit: close, confirming before discarding changes.
  Future<void> _close() async {
    final controller = _controller;
    if (controller == null || controller.submitting) return;
    if (controller.isDirty) {
      final discard = await showGlassConfirmDialog(
        context: context,
        icon: Icons.edit_off_outlined,
        title: 'Discard changes?',
        message: 'Your changes to your dental profile will be lost.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop(false);
  }

  /// Leaving the screen from where "back" has nowhere else to go.
  bool get _atStart {
    final controller = _controller!;
    return _onboarding ? _welcome : controller.onReview || controller.step == 0;
  }

  /// System back: previous slide, or close when editing from review.
  void _onSystemBack() {
    final controller = _controller;
    if (controller == null || controller.submitting) return;
    if (!_atStart) {
      _back();
    } else if (!_onboarding) {
      _close();
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onSystemBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightLavender,
        body: AppBackdrop(
          child: SafeArea(
            child: controller == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => _buildPage(controller),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(DentalQuestionnaireController controller) {
    final key = _welcome ? 'welcome' : 'step-${controller.step}';
    return Column(
      children: [
        _buildTopBar(controller),
        Expanded(
          child: AnimatedSwitcher(
            duration: dentraMotion(context, 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            transitionBuilder: (child, animation) {
              // New slide comes in from the side we're heading to; the
              // old one leaves toward the other.
              final incoming = child.key == ValueKey(key);
              final dx = 0.08 * _direction * (incoming ? 1 : -1);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: Offset(dx, 0), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(key),
              child: _welcome
                  ? _scrollable(const _Welcome())
                  : _scrollable(controller.onReview
                      ? _buildReview(controller)
                      : _buildStep(controller, controller.currentStep!)),
            ),
          ),
        ),
        _buildActions(controller),
      ],
    );
  }

  /// Back (or close), a thin progress line, and sign out.
  Widget _buildTopBar(DentalQuestionnaireController controller) {
    final busy = controller.submitting;
    final Widget? leading = _atStart
        ? (_onboarding
            ? null
            : _BarIcon(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onPressed: busy ? null : _close,
              ))
        : _BarIcon(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: busy ? null : _back,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth + 24),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                leading ?? const SizedBox(width: 48),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedOpacity(
                    duration: dentraMotion(context),
                    opacity: _welcome ? 0 : 1,
                    child: QuestionnaireProgress(
                      step: controller.step,
                      total: dentalSteps.length + 1,
                      label: controller.currentStep?.eyebrow ?? 'Review',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_onboarding)
                  _BarIcon(
                    icon: Icons.logout_rounded,
                    tooltip: 'Sign out',
                    onPressed: busy ? null : _signOut,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scrollable(Widget child) {
    // Content softly fades at the edges instead of being cut off under
    // the top bar and the button, so long slides read as scrollable.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0, 12 / bounds.height, 1 - 28 / bounds.height, 1],
      ).createShader(bounds),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(_gutter, 20, _gutter, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildStep(DentalQuestionnaireController controller, DentalStep step) {
    final answers = controller.answers;
    final enabled = !controller.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Eyebrow(step.eyebrow),
        if (!step.singleQuestion) ...[
          _Heading(step.title!),
          if (step.summary != null) _Subtitle(step.summary!),
        ],
        for (final (i, q) in step.questions.indexed)
          AnimatedSize(
            duration: dentraMotion(context),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !answers.shows(q)
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: EdgeInsets.only(
                      top: step.singleQuestion ? 0 : (i == 0 ? 28 : 36),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        QuestionBlock(
                          key: _questionKeys[q],
                          question: dentalQuestions[q]!,
                          headline: step.singleQuestion,
                          selected: answers.selectedFor(q),
                          error: controller.errors[q],
                          enabled: enabled,
                          onToggle: (option) => controller.toggle(q, option),
                          showsDetail: answers.showsDetail(q),
                          detailController: dentalQuestions[q]!.detail == null
                              ? null
                              : _textFor(q),
                          onDetailChanged: (text) =>
                              controller.setDetail(q, text),
                        ),
                        if (q == DentalQuestionId.discomfortLevel &&
                            answers.needsPromptCare) ...[
                          const SizedBox(height: 6),
                          const PromptCareNote(),
                        ],
                      ],
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildReview(DentalQuestionnaireController controller) {
    final answers = controller.answers.normalized();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Almost done'),
        _Heading(_onboarding ? 'Review your answers' : 'Your dental profile'),
        _Subtitle(_onboarding
            ? 'Check that everything looks right before saving.'
            : 'Tap Edit next to an answer to change it.'),
        const SizedBox(height: 24),
        if (answers.needsPromptCare) ...[
          const PromptCareNote(),
          const SizedBox(height: 12),
        ],
        QuestionnaireReview(
          answers: answers,
          enabled: !controller.submitting,
          onEdit: controller.edit,
        ),
        const SizedBox(height: 18),
        const _FinePrint(
          icon: Icons.lock_outline_rounded,
          text: 'Saved privately to your DENTRA profile and shown as context '
              'with future screenings. Your answers don’t change what DENTRA '
              'detects in photos. DENTRA gives preliminary, smart '
              'screening information and doesn’t replace a dental exam.',
        ),
        DentraInlineNotice(message: controller.submitError),
      ],
    );
  }

  /// One main action at the bottom; Back lives in the top bar.
  Widget _buildActions(DentalQuestionnaireController controller) {
    final Widget button;
    if (_welcome) {
      button = DentraPillButton(label: 'Get started', onPressed: _start);
    } else if (controller.onReview) {
      button = DentraPillButton(
        label: _onboarding ? 'Save and continue' : 'Save changes',
        loadingLabel: 'Saving…',
        loading: controller.submitting,
        // Nothing to send when editing without changes.
        onPressed: _onboarding || controller.isDirty ? _submit : null,
      );
    } else if (controller.canSkip) {
      button = DentraPillButton(
        label: 'Skip this step',
        variant: DentraButtonVariant.outline,
        onPressed: controller.skip,
      );
    } else {
      button = DentraPillButton(
        label: controller.returnsToReview ? 'Back to review' : 'Continue',
        onPressed: _continue,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: SizedBox(width: double.infinity, child: button),
        ),
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// What the questionnaire is for: one illustration, a heading, a line of
/// copy and three quiet facts.
class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const WelcomeIllustration(),
        const SizedBox(height: 28),
        Semantics(
          header: true,
          child: Text(
            'Let’s set up your dental profile',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'A few quick questions so your screenings fit what you’re '
          'noticing.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 15.5,
            color: AppColors.secondaryText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        const _Fact(icon: Icons.schedule_rounded, text: 'About 2 minutes'),
        const _Fact(
          icon: Icons.lock_outline_rounded,
          text: 'Private to your account',
        ),
        const _Fact(
          icon: Icons.edit_outlined,
          text: 'You can change your answers anytime',
        ),
        const SizedBox(height: 20),
        Text(
          'Your answers aren’t a diagnosis and don’t change what DENTRA sees '
          'in your photos.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            color: AppColors.secondaryText,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.g2.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.g2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.g2,
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
          letterSpacing: -0.5,
          height: 1.2,
        ),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 15,
          color: AppColors.secondaryText,
          height: 1.45,
        ),
      ),
    );
  }
}

class _FinePrint extends StatelessWidget {
  const _FinePrint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: AppColors.secondaryText),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: AppColors.secondaryText,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Round, quiet icon button for the top bar. Fixed size, so large text
/// never squeezes the progress line.
class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white.withValues(alpha: 0.7),
        foregroundColor: AppColors.navy,
        fixedSize: const Size(48, 48),
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}
