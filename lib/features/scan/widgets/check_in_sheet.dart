import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../dental_profile/data/models/dental_answers.dart';
import '../../dental_profile/widgets/answer_option_tile.dart';
import '../../dental_profile/widgets/prompt_care_note.dart';
import '../../dental_profile/widgets/question_block.dart'
    show QuestionnaireProgress;
import '../../dental_records/widgets/record_format.dart';
import '../../dental_records/widgets/tooth_number_field.dart';
import '../../screening/data/models/scan_check_in.dart';
import '../data/care_plan.dart';
import '../data/check_in_plan.dart';
import 'mouth_area_picker.dart';
import 'report/report_style.dart';

/// How the sheet closed with an answer. Closing it any other way stays on the
/// start page, so nothing starts by accident.
class CheckInResult {
  const CheckInResult(this.answers);

  /// Null when the user skipped it.
  final ScanCheckIn? answers;
}

/// The few questions worth asking before this scan, one at a time. Every one
/// can be skipped, and the answers never reach the image model.
Future<CheckInResult?> showCheckInSheet(
  BuildContext context,
  CheckInPlan plan,
) {
  final last = plan.lastScanAt;
  return showGlassSheet<CheckInResult>(
    context: context,
    title: 'Before you scan',
    subtitle: last == null
        ? 'A few taps so your advice fits you. Your photos are read the same '
            'either way.'
        : 'Since your last scan on ${DentraDates.medium(last)}. Your photos '
            'are read the same either way.',
    builder: (_) => _CheckInForm(plan: plan),
  );
}

/// Short labels for the tiles. The onboarding's own labels are full sentences.
String _checkupLabel(LastCheckup c) => switch (c) {
      LastCheckup.within6Months => 'Under 6 months',
      LastCheckup.sixTo12Months => '6–12 months',
      LastCheckup.overAYear => 'Over a year',
      LastCheckup.never => 'Never',
      LastCheckup.dontRemember => 'Not sure',
    };

String _cleaningLabel(LastCleaning c) => switch (c) {
      LastCleaning.within6Months => 'Under 6 months',
      LastCleaning.sixTo12Months => '6–12 months',
      LastCleaning.overAYear => 'Over a year',
      LastCleaning.never => 'Never',
      LastCleaning.dontRemember => 'Not sure',
    };

String _symptomLabel(CurrentConcern c) => switch (c) {
      CurrentConcern.toothPain => 'Tooth pain',
      CurrentConcern.sensitivity => 'Sensitivity',
      CurrentConcern.bleedingGums => 'Bleeding gums',
      CurrentConcern.swollenGums => 'Swollen gums',
      CurrentConcern.brokenTooth => 'Broken tooth',
      CurrentConcern.other => 'Other discomfort',
      _ => c.label,
    };

String _startedLabel(ConcernDuration d) => switch (d) {
      ConcernDuration.today => 'Today',
      ConcernDuration.fewDays => 'A few days ago',
      ConcernDuration.fewWeeks => 'A few weeks ago',
      ConcernDuration.monthOrLonger => 'A month or more',
      _ => 'Not sure',
    };

/// One question on screen at a time.
enum _Step {
  symptoms,
  where,
  started,
  pattern,
  severity,
  warnings,
  treatment,
  treatmentDetail,
  checkup,
  cleaning,
  focus,
}

class _CheckInForm extends StatefulWidget {
  const _CheckInForm({required this.plan});

  final CheckInPlan plan;

  @override
  State<_CheckInForm> createState() => _CheckInFormState();
}

class _CheckInFormState extends State<_CheckInForm> {
  late Set<CurrentConcern> _symptoms = widget.plan.prefill.symptoms;
  late AreaAnswer? _symptomArea = widget.plan.prefill.symptomArea;
  late List<String> _symptomTeeth = widget.plan.prefill.symptomTeeth;
  late ConcernDuration? _started = widget.plan.prefill.started;
  late SymptomPattern? _pattern = widget.plan.prefill.pattern;
  late DiscomfortLevel? _severity = widget.plan.prefill.severity;
  late Set<WarningSign> _warnings = widget.plan.prefill.warningSigns;
  LastCheckup? _checkup;
  LastCleaning? _cleaning;
  Set<RecentTreatment> _treatments = const {};
  List<String> _treatmentTeeth = const [];
  TreatmentWhen? _treatmentWhen;
  AreaAnswer? _focusArea;
  List<String> _focusTeeth = const [];

  late _Step _step = _steps.first;

  /// 1 going forward, -1 going back: which way the questions slide.
  int _direction = 1;

  /// Moves on after a one-tap answer.
  Timer? _autoNext;

  /// Long enough to see the answer land before the next question slides in.
  static const _autoNextDelay = Duration(milliseconds: 420);

  ScanCheckIn get _answers => ScanCheckIn(
        symptoms: _symptoms,
        symptomArea: _symptomArea,
        symptomTeeth: _symptomTeeth,
        started: _started,
        pattern: _pattern,
        severity: _severity,
        warningSigns: _warnings,
        lastCheckup: _checkup,
        lastCleaning: _cleaning,
        treatments: _treatments,
        treatmentTeeth: _treatmentTeeth,
        treatmentWhen: _treatmentWhen,
        focusArea: _focusArea,
        focusTeeth: _focusTeeth,
      );

  /// The questions in the plan, with follow-ups only where an answer calls
  /// for them. Follow-ups come after the answer that opens them, so the
  /// question on screen never drops out of the list.
  List<_Step> get _steps {
    final plan = widget.plan;
    final a = _answers;
    return [
      if (plan.asksSymptoms) ...[
        _Step.symptoms,
        if (a.hasSymptom) ...[_Step.where, _Step.started, _Step.pattern],
        if (a.asksSeverity) _Step.severity,
        if (a.hasSymptom && a.asksWarningSigns) _Step.warnings,
      ],
      if (plan.asksTreatment) ...[
        _Step.treatment,
        if (a.hasTreatment) _Step.treatmentDetail,
      ],
      if (plan.asksCheckup) _Step.checkup,
      if (plan.asksCleaning) _Step.cleaning,
      // Where it hurts already says where to pay attention.
      if (plan.asksFocus && !a.hasSymptom) _Step.focus,
    ];
  }

  @override
  void dispose() {
    _autoNext?.cancel();
    super.dispose();
  }

  void _done(ScanCheckIn? answers) {
    _autoNext?.cancel();
    Navigator.of(context).pop(CheckInResult(answers));
  }

  void _finish() {
    final a = _answers;
    _done(a.isEmpty ? null : a.normalized());
  }

  void _go(_Step to, int direction) {
    _autoNext?.cancel();
    setState(() {
      _step = to;
      _direction = direction;
    });
    // Each question starts at the top of the sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = Scrollable.maybeOf(context)?.position;
      if (position == null || position.pixels <= 0) return;
      final motion = dentraMotion(context, 260);
      if (motion == Duration.zero) {
        position.jumpTo(0);
      } else {
        position.animateTo(0, duration: motion, curve: Curves.easeOutCubic);
      }
    });
  }

  void _next() {
    final steps = _steps;
    final i = steps.indexOf(_step);
    if (i < steps.length - 1) _go(steps[i + 1], 1);
  }

  void _back() {
    final steps = _steps;
    final i = steps.indexOf(_step);
    if (i > 0) _go(steps[i - 1], -1);
  }

  /// After a one-tap answer, slides on by itself. Not from the last question,
  /// and not for anyone moving with a screen reader or switch access, who
  /// would lose their place.
  void _moveOnSoon() {
    _autoNext?.cancel();
    if (MediaQuery.accessibleNavigationOf(context)) return;
    final from = _step;
    _autoNext = Timer(_autoNextDelay, () {
      if (!mounted || _step != from) return;
      final steps = _steps;
      final i = steps.indexOf(from);
      if (i >= 0 && i < steps.length - 1) _go(steps[i + 1], 1);
    });
  }

  /// Picks a single answer, or clears it when tapped again. A pick moves on
  /// unless [stay] says the user should read something first.
  void _pick<T>(T? current, T value, void Function(T?) set,
      {bool moveOn = true, bool Function(T)? stay}) {
    final clearing = current == value;
    setState(() => set(clearing ? null : value));
    if (!clearing && moveOn && !(stay?.call(value) ?? false)) {
      _moveOnSoon();
    } else {
      _autoNext?.cancel();
    }
  }

  /// Ticks or unticks an answer; a "none" answer clears the rest, the rest
  /// clear it, and ticking "none" moves on.
  void _toggle<T extends AnswerOption>(
      Set<T> current, T option, void Function(Set<T>) set) {
    final Set<T> next;
    if (current.contains(option)) {
      next = {...current}..remove(option);
    } else if (option.exclusive) {
      next = {option};
    } else {
      next = {...current.where((o) => !o.exclusive), option};
    }
    setState(() => set(next));
    if (option.exclusive && next.contains(option)) {
      _moveOnSoon();
    } else {
      _autoNext?.cancel();
    }
  }

  /// The question, and a line on how to answer when it isn't obvious.
  (String, String?) _copy(_Step step) => switch (step) {
        _Step.symptoms => (
            'Is anything bothering you today?',
            'Pick any that apply.',
          ),
        _Step.where => ('Where is it?', null),
        _Step.started => ('When did it start?', null),
        _Step.pattern => ('How has it been?', null),
        _Step.severity => ('How bad is it?', null),
        _Step.warnings => (
            'Do you have any of these?',
            'Pick any that apply.',
          ),
        _Step.treatment => (
            widget.plan.lastScanAt == null
                ? 'Any dental treatment in the last 3 months?'
                : 'Any dental treatment since then?',
            'Pick any that apply.',
          ),
        _Step.treatmentDetail => ('When, and on which tooth?', null),
        _Step.checkup => ('When was your last check-up?', null),
        _Step.cleaning => (
            widget.plan.asksCheckup
                ? 'And your last professional cleaning?'
                : 'When was your last professional cleaning?',
            null,
          ),
        _Step.focus => ('Any tooth or area you\'d like noted?', null),
      };

  Widget _content(_Step step, ScanCheckIn a) => switch (step) {
        _Step.symptoms => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnswerOptionTile(
                label: 'Nothing right now',
                compact: true,
                multiple: true,
                selected: _symptoms.contains(CurrentConcern.none),
                onTap: () => _toggle(
                    _symptoms, CurrentConcern.none, (v) => _symptoms = v),
              ),
              const SizedBox(height: 8),
              _Tiles<CurrentConcern>(
                options: checkInSymptoms,
                columns: 2,
                multiple: true,
                labelOf: _symptomLabel,
                isSelected: _symptoms.contains,
                onTap: (c) => _toggle(_symptoms, c, (v) => _symptoms = v),
              ),
            ],
          ),
        _Step.where => _AreaAndTooth(
            area: _symptomArea,
            teeth: _symptomTeeth,
            onArea: (v) =>
                setState(() => _symptomArea = _symptomArea == v ? null : v),
            onTeeth: (v) => setState(() => _symptomTeeth = v),
          ),
        _Step.started => _Tiles<ConcernDuration>(
            options: symptomStarts,
            columns: 2,
            labelOf: _startedLabel,
            isSelected: (d) => _started == d,
            onTap: (d) => _pick(_started, d, (v) => _started = v),
          ),
        _Step.pattern => _Tiles<SymptomPattern>(
            options: SymptomPattern.values,
            labelOf: (p) => p.label,
            isSelected: (p) => _pattern == p,
            onTap: (p) => _pick(_pattern, p, (v) => _pattern = v),
          ),
        _Step.severity => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SeverityScale(
                value: _severity,
                onTap: (d) => _pick(
                  _severity,
                  d,
                  (v) => _severity = v,
                  // The care note below needs reading first.
                  stay: (level) => level == DiscomfortLevel.severe,
                ),
              ),
              _Reveal(
                show: a.severity == DiscomfortLevel.severe,
                child: const PromptCareNote(),
              ),
            ],
          ),
        _Step.warnings => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Tiles<WarningSign>(
                options: WarningSign.values,
                columns: 1,
                multiple: true,
                labelOf: (w) => w.label,
                isSelected: _warnings.contains,
                onTap: (w) => _toggle(_warnings, w, (v) => _warnings = v),
              ),
              _Reveal(
                show: a.needsEmergencyCare,
                child: const _EmergencyNote(),
              ),
            ],
          ),
        _Step.treatment => _Tiles<RecentTreatment>(
            options: RecentTreatment.values,
            columns: 2,
            multiple: true,
            labelOf: (t) => t.label,
            isSelected: _treatments.contains,
            onTap: (t) => _toggle(_treatments, t, (v) => _treatments = v),
          ),
        _Step.treatmentDetail => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Tiles<TreatmentWhen>(
                options: TreatmentWhen.values,
                columns: 2,
                labelOf: (w) => w.label,
                isSelected: (w) => _treatmentWhen == w,
                // The tooth is asked on the same screen, so this waits.
                onTap: (w) => _pick(
                    _treatmentWhen, w, (v) => _treatmentWhen = v,
                    moveOn: false),
              ),
              const SizedBox(height: 8),
              _ToothTile(
                teeth: _treatmentTeeth,
                onChanged: (v) => setState(() => _treatmentTeeth = v),
              ),
            ],
          ),
        _Step.checkup => _Tiles<LastCheckup>(
            options: LastCheckup.values,
            labelOf: _checkupLabel,
            isSelected: (c) => _checkup == c,
            onTap: (c) => _pick(_checkup, c, (v) => _checkup = v),
          ),
        _Step.cleaning => _Tiles<LastCleaning>(
            options: LastCleaning.values,
            labelOf: _cleaningLabel,
            isSelected: (c) => _cleaning == c,
            onTap: (c) => _pick(_cleaning, c, (v) => _cleaning = v),
          ),
        _Step.focus => _AreaAndTooth(
            area: _focusArea,
            teeth: _focusTeeth,
            onArea: (v) =>
                setState(() => _focusArea = _focusArea == v ? null : v),
            onTeeth: (v) => setState(() => _focusTeeth = v),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final index = steps.indexOf(_step).clamp(0, steps.length - 1);
    final step = steps[index];
    final last = index == steps.length - 1;
    final (title, hint) = _copy(step);
    final motion = dentraMotion(context, 320);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressRow(
          step: index,
          total: steps.length,
          label: title,
          onBack: index > 0 ? _back : null,
        ),
        const SizedBox(height: 20),
        AnimatedSize(
          duration: motion,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: motion,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            // Only the new question sizes the sheet, so it resizes while
            // the old one slides out over it.
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.topCenter,
              children: [
                for (final old in previous)
                  Positioned(top: 0, left: 0, right: 0, child: old),
                if (current != null) current,
              ],
            ),
            transitionBuilder: (child, animation) {
              // The new question comes in from the side we're heading to;
              // the old one leaves toward the other.
              final incoming = child.key == ValueKey(step);
              final dx = 0.14 * _direction * (incoming ? 1 : -1);
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
              key: ValueKey(step),
              child: _Question(
                title: title,
                hint: hint,
                child: _content(step, _answers),
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        DentraButtonRow(
          secondary: DentraPillButton(
            label: 'Skip for now',
            variant: DentraButtonVariant.outline,
            onPressed: () => _done(null),
          ),
          primary: DentraPillButton(
            label: last ? 'Continue' : 'Next',
            onPressed: last ? _finish : _next,
          ),
        ),
      ],
    );
  }
}

/// Back, and a thin line for how far along the questions are.
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.step,
    required this.total,
    required this.label,
    required this.onBack,
  });

  final int step;
  final int total;
  final String label;

  /// Null on the first question.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Back slides in from the second question; the line makes room.
        AnimatedSize(
          duration: dentraMotion(context, 260),
          curve: Curves.easeOutCubic,
          child: onBack == null
              ? const SizedBox(height: 44)
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    onPressed: onBack,
                    tooltip: 'Back',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.white.withValues(alpha: 0.7),
                      foregroundColor: AppColors.navy,
                      fixedSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
        ),
        Expanded(
          child: QuestionnaireProgress(step: step, total: total, label: label),
        ),
      ],
    );
  }
}

/// The question in large type over its answers.
class _Question extends StatelessWidget {
  const _Question({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}

/// A grid of small answer tiles: fewer columns when the text is large.
class _Tiles<T extends AnswerOption> extends StatelessWidget {
  const _Tiles({
    required this.options,
    required this.labelOf,
    required this.isSelected,
    required this.onTap,
    this.columns = 3,
    this.multiple = false,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final bool Function(T) isSelected;
  final ValueChanged<T> onTap;
  final int columns;

  /// Read by screen readers as checkboxes rather than radio buttons.
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 8.0;
      final fit = (constraints.maxWidth / scale / 96).floor().clamp(1, columns);
      final width = (constraints.maxWidth - gap * (fit - 1)) / fit;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final o in options)
            SizedBox(
              width: width,
              child: AnswerOptionTile(
                label: labelOf(o),
                compact: true,
                multiple: multiple,
                selected: isSelected(o),
                onTap: () => onTap(o),
              ),
            ),
        ],
      );
    });
  }
}

/// Which general area, tapped on a map of the mouth, and the tooth if they
/// know it.
class _AreaAndTooth extends StatelessWidget {
  const _AreaAndTooth({
    required this.area,
    required this.teeth,
    required this.onArea,
    required this.onTeeth,
  });

  final AreaAnswer? area;
  final List<String> teeth;
  final ValueChanged<AreaAnswer> onArea;
  final ValueChanged<List<String>> onTeeth;

  @override
  Widget build(BuildContext context) {
    final onMap = area != null && area != AreaAnswer.notSure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouthAreaPicker(selected: area, onSelect: onArea),
        const SizedBox(height: 14),
        // What's picked, in words, under the map.
        ExcludeSemantics(
          child: AnimatedSwitcher(
            duration: dentraMotion(context, 180),
            child: Text(
              onMap ? area!.label : 'Tap an area',
              key: ValueKey(onMap ? area : null),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: onMap ? FontWeight.w700 : FontWeight.w500,
                color: onMap ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AnswerOptionTile(
                label: AreaAnswer.notSure.label,
                compact: true,
                multiple: false,
                selected: area == AreaAnswer.notSure,
                onTap: () => onArea(AreaAnswer.notSure),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _ToothTile(teeth: teeth, onChanged: onTeeth)),
          ],
        ),
      ],
    );
  }
}

/// Opens the tooth chart. Filled once a tooth is chosen; the chart can clear
/// it again.
class _ToothTile extends StatelessWidget {
  const _ToothTile({required this.teeth, required this.onChanged});

  final List<String> teeth;
  final ValueChanged<List<String>> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await pickTeeth(context, teeth);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = teeth.isEmpty ? 'Add a tooth' : teethLabel(teeth);
    return Semantics(
      button: true,
      label: teeth.isEmpty ? 'Add a tooth number' : label,
      hint: 'Opens tooth chart',
      onTap: () => _open(context),
      excludeSemantics: true,
      child: AnswerOptionTile(
        label: label,
        compact: true,
        multiple: true,
        selected: teeth.isNotEmpty,
        onTap: () => _open(context),
      ),
    );
  }
}

/// Mild, moderate, severe as three rising bars that fill up to the answer,
/// in the teal ramp the results use.
class _SeverityScale extends StatelessWidget {
  const _SeverityScale({required this.value, required this.onTap});

  final DiscomfortLevel? value;
  final ValueChanged<DiscomfortLevel> onTap;

  static const _levels = [
    DiscomfortLevel.mild,
    DiscomfortLevel.moderate,
    DiscomfortLevel.severe,
  ];
  static const _fills = [AppColors.g1, AppColors.g2, ReportColors.strong];

  @override
  Widget build(BuildContext context) {
    final chosen = value == null ? -1 : _levels.indexOf(value!);
    final motion = dentraMotion(context, 240);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppGlass.fillLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.g2.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, level) in _levels.indexed)
            Expanded(
              child: MergeSemantics(
                child: Semantics(
                  checked: i == chosen,
                  inMutuallyExclusiveGroup: true,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => onTap(level),
                      borderRadius: BorderRadius.circular(16),
                      focusColor: AppColors.g2.withValues(alpha: 0.12),
                      splashColor: AppColors.g2.withValues(alpha: 0.08),
                      highlightColor: AppColors.g2.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: motion,
                              curve: Curves.easeOutCubic,
                              width: 12,
                              height: 14.0 + 10 * i,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: i <= chosen
                                    ? _fills[i]
                                    : AppColors.g2.withValues(alpha: 0.12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              level.label,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: i == chosen
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grows in under the answers when [show] turns on.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: dentraMotion(context),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: show
          ? Padding(padding: const EdgeInsets.only(top: 14), child: child)
          : const SizedBox(width: double.infinity),
    );
  }
}

/// Reported signs that shouldn't wait for a scan, shown as soon as they're
/// ticked. Solid deep teal: the one loud thing on this sheet.
class _EmergencyNote extends StatelessWidget {
  const _EmergencyNote();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ReportColors.strong,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CareLevel.emergency.title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Don\'t wait to scan. Call your local emergency number or go to '
              'the nearest emergency department. Don\'t drive yourself.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.45,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
