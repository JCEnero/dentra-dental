import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../data/dental_questions.dart';
import '../data/models/dental_answers.dart';
import 'answer_option_tile.dart';

/// One question: its text, helper line, any error, the answer rows and,
/// when relevant, a free-text box (e.g. after "Other").
class QuestionBlock extends StatelessWidget {
  const QuestionBlock({
    super.key,
    required this.question,
    required this.selected,
    required this.onToggle,
    required this.showsDetail,
    required this.detailController,
    required this.onDetailChanged,
    this.error,
    this.enabled = true,
    this.headline = false,
  });

  final DentalQuestion question;
  final Set<AnswerOption> selected;
  final ValueChanged<AnswerOption> onToggle;
  final bool showsDetail;
  final TextEditingController? detailController;
  final ValueChanged<String> onDetailChanged;
  final String? error;
  final bool enabled;

  /// The question is the slide's heading (a single-question slide).
  final bool headline;

  @override
  Widget build(BuildContext context) {
    final detail = question.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            question.title,
            style: GoogleFonts.outfit(
              fontSize: headline ? 26 : 18,
              fontWeight: headline ? FontWeight.w800 : FontWeight.w700,
              color: AppColors.navy,
              letterSpacing: headline ? -0.5 : -0.2,
              height: headline ? 1.2 : 1.3,
            ),
          ),
        ),
        if (question.helper != null || question.optional) ...[
          SizedBox(height: headline ? 8 : 4),
          Text(
            [
              if (question.optional && !question.textOnly) 'Optional.',
              if (question.helper != null) question.helper!,
            ].join(' '),
            style: GoogleFonts.outfit(
              fontSize: headline ? 15 : 13.5,
              color: AppColors.secondaryText,
              height: 1.45,
            ),
          ),
        ],
        _ErrorLine(message: error),
        if (!question.textOnly) ...[
          SizedBox(height: headline ? 24 : 16),
          for (final option in question.options) ...[
            AnswerOptionTile(
              label: option.label,
              selected: selected.contains(option),
              multiple: question.multiple,
              onTap: enabled ? () => onToggle(option) : null,
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (detail != null && detailController != null)
          AnimatedSize(
            duration: dentraMotion(context),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: showsDetail
                ? Padding(
                    padding: EdgeInsets.only(top: question.textOnly ? 14 : 6),
                    child: DetailTextField(
                      field: detail,
                      controller: detailController!,
                      enabled: enabled,
                      onChanged: onDetailChanged,
                      // The text-only question already reads as its label.
                      showLabel: !question.textOnly,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: dentraMotion(context, 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 15, color: AppColors.coral),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        message!,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Free-text input styled like the app's other form fields, with a
/// character limit and counter.
class DetailTextField extends StatelessWidget {
  const DetailTextField({
    super.key,
    required this.field,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.showLabel = true,
  });

  final DentalDetailField field;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      field.label,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
        letterSpacing: 0.1,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[label, const SizedBox(height: 7)],
        TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          maxLength: field.maxLength,
          minLines: field.multiline ? 3 : 1,
          maxLines: field.multiline ? 6 : 2,
          keyboardType:
              field.multiline ? TextInputType.multiline : TextInputType.text,
          textInputAction:
              field.multiline ? TextInputAction.newline : TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.navy,
            height: 1.4,
          ),
          decoration: InputDecoration(
            // Screen readers still get the label when it isn't drawn.
            labelText: showLabel ? null : field.label,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            hintText: field.hint,
            hintStyle: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.secondaryText.withValues(alpha: 0.6),
            ),
            counterStyle: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: AppColors.lightLavender,
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.border),
            ),
            disabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// A thin bar that fills as the questionnaire advances, with a short
/// "2 of 6" count. The last step is review.
class QuestionnaireProgress extends StatelessWidget {
  const QuestionnaireProgress({
    super.key,
    required this.step,
    required this.total,
    required this.label,
  });

  /// Zero-based.
  final int step;
  final int total;

  /// Name of the current step, for screen readers.
  final String label;

  @override
  Widget build(BuildContext context) {
    final count = '${step + 1} of $total';
    return Semantics(
      liveRegion: true,
      label: 'Step $count, $label',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: AppColors.g2.withValues(alpha: 0.12)),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: (step + 1) / total),
                        duration: dentraMotion(context, 380),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              count,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
