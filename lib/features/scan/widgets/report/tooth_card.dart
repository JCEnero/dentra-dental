import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../dental_profile/widgets/answer_option_tile.dart';
import '../../../screening/data/models/finding_answer.dart';
import '../../data/care_plan.dart';
import '../../data/tooth_guidance.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import 'report_charts.dart';
import 'report_style.dart';

/// Everything about one marked tooth, under its photo, most important first:
/// what was found, the question about pain, and what to do and how soon. What
/// it could mean and the treatments a dentist may consider wait in folds.
class ToothDetails extends StatelessWidget {
  const ToothDetails({
    super.key,
    required this.guidance,
    this.onAnswer,
    this.onLearnMore,
  });

  final ToothGuidance guidance;

  /// Saves an answer about this tooth, or takes it back with null. Null when it
  /// can't be saved here, which leaves the question out.
  final ValueChanged<ToothPain?>? onAnswer;

  /// Opens a procedure's page in the Treatment tab.
  final ValueChanged<String>? onLearnMore;

  @override
  Widget build(BuildContext context) {
    final g = guidance;
    final confidence = g.spot.finding.confidence;
    final onAnswer = this.onAnswer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(g.where, style: reportCardTitle),
                    Text(g.spot.strength.label, style: reportNote),
                  ],
                ),
              ),
            ),
            if (confidence != null)
              Semantics(
                label: '${(confidence * 100).round()} percent model confidence',
                excludeSemantics: true,
                child: ConfidenceGauge(
                  value: confidence,
                  color: ReportColors.ofSign(g.spot.strength),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('What we found', style: reportLabel),
        const SizedBox(height: 2),
        Text(g.found, style: reportBody),
        if (g.asks && onAnswer != null) ...[
          const SizedBox(height: 14),
          PainQuestion(guidance: g, onAnswer: onAnswer),
        ],
        const SizedBox(height: 14),
        _NextStep(guidance: g),
        const SizedBox(height: 6),
        ReportFold(
          title: 'What this could mean',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.meaning, style: reportBody),
              const SizedBox(height: 10),
              Text('Why it matters', style: reportLabel),
              const SizedBox(height: 2),
              Text(g.why, style: reportBody),
            ],
          ),
        ),
        if (g.treatments.isNotEmpty)
          ReportFold(
            title: 'Possible treatments',
            count: g.treatments.length,
            child: _Treatments(guidance: g, onLearnMore: onLearnMore),
          ),
      ],
    );
  }
}

/// "Have you experienced pain or sensitivity in this tooth before?", with the
/// four answers. Once answered it folds to the answer and what it means, with a
/// way to change it. Every answer is optional.
class PainQuestion extends StatefulWidget {
  const PainQuestion({
    super.key,
    required this.guidance,
    required this.onAnswer,
  });

  final ToothGuidance guidance;
  final ValueChanged<ToothPain?> onAnswer;

  static const question =
      'Have you experienced pain or sensitivity in this tooth before?';

  @override
  State<PainQuestion> createState() => _PainQuestionState();
}

class _PainQuestionState extends State<PainQuestion> {
  bool _changing = false;

  void _pick(ToothPain pain) {
    setState(() => _changing = false);
    if (pain != widget.guidance.pain) widget.onAnswer(pain);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guidance;
    final answer = g.pain;
    final asking = answer == null || _changing;
    return AnimatedSize(
      duration: ScanMotion.of(context, ScanMotion.medium),
      curve: ScanMotion.curve,
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.g2.withValues(alpha: 0.14)),
        ),
        child: asking
            ? _asking(answer)
            : _answered(answer, g.answerNote, g.symptomsToWatch),
      ),
    );
  }

  Widget _asking(ToothPain? answer) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(PainQuestion.question, style: reportCardTitle),
          ),
          const SizedBox(height: 2),
          Text(
            'Optional. It changes the advice for this tooth, never what the '
            'check found.',
            style: reportNote,
          ),
          const SizedBox(height: 10),
          for (final pain in ToothPain.values) ...[
            AnswerOptionTile(
              label: pain.label,
              selected: answer == pain,
              multiple: false,
              onTap: () => _pick(pain),
            ),
            const SizedBox(height: 6),
          ],
          if (answer != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TextAction(
                  label: 'Remove my answer',
                  onPressed: () {
                    setState(() => _changing = false);
                    widget.onAnswer(null);
                  },
                ),
                _TextAction(
                  label: 'Keep it',
                  onPressed: () => setState(() => _changing = false),
                ),
              ],
            ),
        ],
      );

  Widget _answered(ToothPain answer, String? note, List<String> watch) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('You told us', style: reportLabel)),
              _TextAction(
                label: 'Change',
                semanticLabel: 'Change your answer about this tooth',
                onPressed: () => setState(() => _changing = true),
              ),
            ],
          ),
          Text(answer.label, style: reportCardTitle),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note, style: reportBody),
          ],
          for (final sign in watch)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 7, right: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.g2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: Text(sign, style: reportBody)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Saved with this screening. It shapes the advice, not the finding.',
            style: reportNote,
          ),
        ],
      );
}

/// What to do next for this tooth, how soon, and why.
class _NextStep extends StatelessWidget {
  const _NextStep({required this.guidance});

  final ToothGuidance guidance;

  IconData get _icon => switch (guidance.urgency) {
        ToothUrgency.prompt => Icons.priority_high_rounded,
        ToothUrgency.soon => Icons.event_outlined,
        ToothUrgency.routine => Icons.event_note_outlined,
        ToothUrgency.watch => Icons.visibility_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final g = guidance;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.g2.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScanIconDisc(_icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What to do next', style: reportLabel),
                Text(
                  g.urgency.title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(g.nextStep, style: reportBody),
                const SizedBox(height: 4),
                Text(
                  '${g.urgencyWhy} ${careSourcesInWords(g.sources)}.',
                  style: reportNote,
                ),
                if (g.warnsAboutUrgentCare) ...[
                  const SizedBox(height: 6),
                  Text(
                    urgentCareWarning,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: ScanColors.clearInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What a dentist may consider, each with a way into its page in the Treatment
/// tab, and what decides between them.
class _Treatments extends StatelessWidget {
  const _Treatments({required this.guidance, this.onLearnMore});

  final ToothGuidance guidance;
  final ValueChanged<String>? onLearnMore;

  @override
  Widget build(BuildContext context) {
    final g = guidance;
    final learnMore = onLearnMore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A dentist may consider one of these. They aren\'t a diagnosis or a '
          'plan.',
          style: reportNote,
        ),
        for (final option in g.treatments) ...[
          const SizedBox(height: 10),
          Text(option.name, style: reportCardTitle),
          const SizedBox(height: 1),
          Text(option.when, style: reportBody),
          if (learnMore != null)
            _TextAction(
              label: Procedures.learnMore(option.treatmentId),
              icon: Icons.menu_book_outlined,
              onPressed: () => learnMore(option.treatmentId),
            ),
        ],
        if (g.treatmentNote case final note?) ...[
          const SizedBox(height: 8),
          Text(note, style: reportNote),
        ],
        // Said once per tooth: next to what to do when the tooth hurts.
        if (!g.warnsAboutUrgentCare) ...[
          const SizedBox(height: 6),
          Text(urgentCareWarning, style: reportNote),
        ],
      ],
    );
  }
}

/// A quiet teal text button, at least 44 points tall.
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: ScanColors.clearInk,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerLeft,
      textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
    );
    final text = Text(label, semanticsLabel: semanticLabel);
    return icon == null
        ? TextButton(onPressed: onPressed, style: style, child: text)
        : TextButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            // The button already lets its label wrap.
            label: text,
          );
  }
}
