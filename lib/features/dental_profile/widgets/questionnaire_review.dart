import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../data/dental_questions.dart';
import '../data/models/dental_answers.dart';

/// Every answer in one quiet list. Each row has an Edit link that opens
/// the slide it was answered on. Hidden follow-up questions are left out.
class QuestionnaireReview extends StatelessWidget {
  const QuestionnaireReview({
    super.key,
    required this.answers,
    required this.onEdit,
    this.enabled = true,
  });

  /// Normalized answers (what will be saved).
  final DentalAnswers answers;

  /// Opens the step at this index.
  final ValueChanged<int> onEdit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (var i = 0; i < dentalSteps.length; i++)
        for (final q in dentalSteps[i].questions)
          if (answers.shows(q))
            _ReviewRow(
              question: dentalQuestions[q]!,
              answers: answers,
              onEdit: enabled ? () => onEdit(i) : null,
            ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppGlass.fillLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.g2.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 18,
                  endIndent: 18,
                  color: AppGlass.divider,
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.question,
    required this.answers,
    required this.onEdit,
  });

  final DentalQuestion question;
  final DentalAnswers answers;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final selected = answers.selectedFor(question.id);
    final detail = answers.detailFor(question.id);
    final value = question.textOnly
        ? (detail.isEmpty ? 'Not provided' : detail)
        : selected.isEmpty
            ? (question.optional ? 'Skipped' : 'Not answered')
            : selected.map((o) => o.label).join(', ');
    final empty = value == 'Not provided' || value == 'Skipped';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.reviewLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
                      color: empty ? AppColors.secondaryText : AppColors.navy,
                      height: 1.4,
                    ),
                  ),
                  if (!question.textOnly && detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '“$detail”',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.navy.withValues(alpha: 0.75),
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Semantics(
            label: 'Edit ${question.reviewLabel.toLowerCase()}',
            button: true,
            excludeSemantics: true,
            child: TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.g2,
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                'Edit',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
