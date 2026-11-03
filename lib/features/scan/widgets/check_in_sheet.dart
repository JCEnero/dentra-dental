import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../dental_profile/data/models/dental_answers.dart';
import '../../dental_profile/widgets/answer_option_tile.dart';
import '../../dental_profile/widgets/prompt_care_note.dart';
import '../../dental_records/widgets/tooth_number_field.dart';
import '../../screening/data/models/scan_check_in.dart';
import '../data/care_plan.dart';
import '../data/check_in_plan.dart';
import 'report/report_style.dart';

/// How the sheet closed with an answer. Closing it any other way stays on the
/// start page, so nothing starts by accident.
class CheckInResult {
  const CheckInResult(this.answers);

  /// Null when the user skipped it.
  final ScanCheckIn? answers;
}

/// The few questions worth asking before this scan. Every one can be skipped,
/// and the answers never reach the image model.
Future<CheckInResult?> showCheckInSheet(
  BuildContext context,
  CheckInPlan plan,
) {
  final last = plan.lastScanAt;
  return showGlassSheet<CheckInResult>(
    context: context,
    title: 'Before you scan',
    subtitle: last == null
        ? 'A few quick questions so your result fits you. They don\'t change '
            'what the check sees in your photos.'
        : 'Since your last scan on ${DentraDates.medium(last)}. Your answers '
            'don\'t change what the check sees in your photos.',
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

  void _done(ScanCheckIn? answers) =>
      Navigator.of(context).pop(CheckInResult(answers));

  /// Tick or untick an answer; a "none" answer clears the rest, and the rest
  /// clear it.
  Set<T> _toggled<T extends AnswerOption>(Set<T> current, T option) {
    if (current.contains(option)) return {...current}..remove(option);
    if (option.exclusive) return {option};
    return {...current.where((o) => !o.exclusive), option};
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final a = _answers;
    final sections = <Widget>[
      if (plan.asksSymptoms) ...[
        _Question(
          title: 'Is anything bothering you today?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnswerOptionTile(
                label: 'Nothing right now',
                compact: true,
                multiple: true,
                selected: _symptoms.contains(CurrentConcern.none),
                onTap: () => setState(
                    () => _symptoms = _toggled(_symptoms, CurrentConcern.none)),
              ),
              const SizedBox(height: 8),
              _Tiles<CurrentConcern>(
                options: checkInSymptoms,
                columns: 2,
                multiple: true,
                labelOf: _symptomLabel,
                isSelected: _symptoms.contains,
                onTap: (c) =>
                    setState(() => _symptoms = _toggled(_symptoms, c)),
              ),
            ],
          ),
        ),
        if (a.hasSymptom) ...[
          _Question(
            title: 'Where is it?',
            optional: true,
            child: _AreaAndTooth(
              area: _symptomArea,
              teeth: _symptomTeeth,
              onArea: (v) =>
                  setState(() => _symptomArea = _symptomArea == v ? null : v),
              onTeeth: (v) => setState(() => _symptomTeeth = v),
            ),
          ),
          _Question(
            title: 'When did it start?',
            optional: true,
            child: _Tiles<ConcernDuration>(
              options: symptomStarts,
              columns: 2,
              labelOf: _startedLabel,
              isSelected: (d) => _started == d,
              onTap: (d) => setState(() => _started = _started == d ? null : d),
            ),
          ),
          _Question(
            title: 'How has it been?',
            optional: true,
            child: _Tiles<SymptomPattern>(
              options: SymptomPattern.values,
              labelOf: (p) => p.label,
              isSelected: (p) => _pattern == p,
              onTap: (p) => setState(() => _pattern = _pattern == p ? null : p),
            ),
          ),
        ],
        if (a.asksSeverity)
          _Question(
            title: 'How bad is it?',
            optional: true,
            child: _Tiles<DiscomfortLevel>(
              options: const [
                DiscomfortLevel.mild,
                DiscomfortLevel.moderate,
                DiscomfortLevel.severe,
              ],
              labelOf: (d) => d.label,
              isSelected: (d) => _severity == d,
              onTap: (d) =>
                  setState(() => _severity = _severity == d ? null : d),
            ),
          ),
        if (a.severity == DiscomfortLevel.severe) ...[
          const PromptCareNote(),
          const SizedBox(height: 18),
        ],
        if (a.hasSymptom && a.asksWarningSigns) ...[
          _Question(
            title: 'Do you have any of these?',
            child: _Tiles<WarningSign>(
              options: WarningSign.values,
              columns: 1,
              multiple: true,
              labelOf: (w) => w.label,
              isSelected: _warnings.contains,
              onTap: (w) => setState(() => _warnings = _toggled(_warnings, w)),
            ),
          ),
          if (a.needsEmergencyCare) ...[
            const _EmergencyNote(),
            const SizedBox(height: 18),
          ],
        ],
      ],
      if (plan.asksTreatment) ...[
        _Question(
          title: plan.lastScanAt == null
              ? 'Any dental treatment in the last 3 months?'
              : 'Any dental treatment since then?',
          optional: true,
          child: _Tiles<RecentTreatment>(
            options: RecentTreatment.values,
            columns: 2,
            multiple: true,
            labelOf: (t) => t.label,
            isSelected: _treatments.contains,
            onTap: (t) =>
                setState(() => _treatments = _toggled(_treatments, t)),
          ),
        ),
        if (a.hasTreatment)
          _Question(
            title: 'When, and on which tooth?',
            optional: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Tiles<TreatmentWhen>(
                  options: TreatmentWhen.values,
                  columns: 2,
                  labelOf: (w) => w.label,
                  isSelected: (w) => _treatmentWhen == w,
                  onTap: (w) => setState(
                      () => _treatmentWhen = _treatmentWhen == w ? null : w),
                ),
                const SizedBox(height: 12),
                ToothNumberField(
                  value: _treatmentTeeth,
                  onChanged: (v) => setState(() => _treatmentTeeth = v),
                ),
              ],
            ),
          ),
      ],
      if (plan.asksCheckup)
        _Question(
          title: 'When was your last check-up?',
          optional: true,
          child: _Tiles<LastCheckup>(
            options: LastCheckup.values,
            labelOf: _checkupLabel,
            isSelected: (c) => _checkup == c,
            onTap: (c) => setState(() => _checkup = _checkup == c ? null : c),
          ),
        ),
      if (plan.asksCleaning)
        _Question(
          title: 'And your last professional cleaning?',
          optional: true,
          child: _Tiles<LastCleaning>(
            options: LastCleaning.values,
            labelOf: _cleaningLabel,
            isSelected: (c) => _cleaning == c,
            onTap: (c) => setState(() => _cleaning = _cleaning == c ? null : c),
          ),
        ),
      // Where it hurts already says where to pay attention.
      if (plan.asksFocus && !a.hasSymptom)
        _Question(
          title: 'Any tooth or area you\'d like noted?',
          optional: true,
          child: _AreaAndTooth(
            area: _focusArea,
            teeth: _focusTeeth,
            onArea: (v) =>
                setState(() => _focusArea = _focusArea == v ? null : v),
            onTeeth: (v) => setState(() => _focusTeeth = v),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...sections,
        const SizedBox(height: 4),
        DentraButtonRow(
          secondary: DentraPillButton(
            label: 'Skip for now',
            variant: DentraButtonVariant.outline,
            onPressed: () => _done(null),
          ),
          primary: DentraPillButton(
            label: 'Continue',
            onPressed: () => _done(a.isEmpty ? null : a.normalized()),
          ),
        ),
      ],
    );
  }
}

/// A question, marked when it can be skipped on its own.
class _Question extends StatelessWidget {
  const _Question({
    required this.title,
    required this.child,
    this.optional = false,
  });

  final String title;
  final Widget child;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
              if (optional) Text('Optional', style: reportNote),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
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

/// Which general area and, if they know it, which tooth.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Tiles<AreaAnswer>(
          options: AreaAnswer.values,
          labelOf: (a) => a.label,
          isSelected: (a) => area == a,
          onTap: onArea,
        ),
        const SizedBox(height: 12),
        ToothNumberField(value: teeth, onChanged: onTeeth),
      ],
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
