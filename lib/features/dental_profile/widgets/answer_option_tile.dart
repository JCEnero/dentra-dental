import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../core/constants/app_glass.dart';

/// A full-width answer row: the label, and a check (multiple choice) or
/// radio (single choice) mark at the end. Read by screen readers as one
/// checkbox or radio button; focusable and activated with Enter or Space.
class AnswerOptionTile extends StatelessWidget {
  const AnswerOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.multiple,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// Checkbox when true, radio button otherwise.
  final bool multiple;

  /// Null disables the row (e.g. while saving).
  final VoidCallback? onTap;

  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final motion = dentraMotion(context, 180);
    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: !multiple,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: _radius,
            focusColor: AppColors.g2.withValues(alpha: 0.12),
            splashColor: AppColors.g2.withValues(alpha: 0.08),
            highlightColor: AppColors.g2.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: motion,
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              decoration: BoxDecoration(
                borderRadius: _radius,
                color: selected
                    ? Color.alphaBlend(
                        AppColors.g2.withValues(alpha: 0.09), AppGlass.fillHigh)
                    : AppGlass.fillLow,
                border: Border.all(
                  color: selected
                      ? AppColors.g2
                      : AppColors.g2.withValues(alpha: 0.10),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: AppColors.navy,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Mark(selected: selected, multiple: multiple, duration: motion),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled teal check when selected; a faint outline otherwise. Rounded
/// square for multiple choice, circle for single choice.
class _Mark extends StatelessWidget {
  const _Mark({
    required this.selected,
    required this.multiple,
    required this.duration,
  });

  final bool selected;
  final bool multiple;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final shape = multiple
        ? BoxDecoration(borderRadius: BorderRadius.circular(7))
        : const BoxDecoration(shape: BoxShape.circle);
    return AnimatedContainer(
      duration: duration,
      width: 24,
      height: 24,
      decoration: shape.copyWith(
        color: selected ? AppColors.g2 : Colors.transparent,
        border: Border.all(
          color: selected
              ? AppColors.g2
              : AppColors.secondaryText.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: AnimatedScale(
        duration: duration,
        curve: Curves.easeOutBack,
        scale: selected ? 1 : 0,
        child: const Icon(Icons.check_rounded, size: 16, color: AppColors.white),
      ),
    );
  }
}
