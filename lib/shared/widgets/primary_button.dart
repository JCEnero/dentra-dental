import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

enum ButtonVariant { primary, secondary, white }

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final ButtonVariant variant;
  final Widget? trailing;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = ButtonVariant.primary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isSecondary = variant == ButtonVariant.secondary;
    final isWhite = variant == ButtonVariant.white;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              gradient:
                  isSecondary || isWhite ? null : AppColors.primaryGradient,
              color: isWhite
                  ? AppColors.white
                  : isSecondary
                      ? Colors.transparent
                      : null,
              borderRadius: BorderRadius.circular(12),
              border: isSecondary
                  ? Border.all(color: AppColors.border, width: 1.5)
                  : null,
              boxShadow: (!isSecondary && !isWhite)
                  ? [
                      BoxShadow(
                        color: AppColors.g2.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Flexible so long labels at large text sizes wrap
                  // instead of overflowing; short labels are unaffected.
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isWhite
                            ? AppColors.g2
                            : isSecondary
                                ? AppColors.secondaryText
                                : AppColors.white,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
