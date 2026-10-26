import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// Standard page header: a small "DENTRA" label above the page title,
/// with an optional back button, trailing action and content below.
///
/// Every main page uses this so titles look the same across the app.
class DentraPageHeader extends StatelessWidget {
  const DentraPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.bottom,
  });

  final String title;

  /// Shows a back button when set.
  final VoidCallback? onBack;

  /// Optional action aligned to the right of the title.
  final Widget? trailing;

  /// Optional content under the title (progress, search field, ...).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 28, AppSpacing.screenH, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                DentraBackButton(onPressed: onBack!),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DENTRA',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 14),
            bottom!,
          ],
        ],
      ),
    );
  }
}

/// Round back button used by [DentraPageHeader].
class DentraBackButton extends StatelessWidget {
  const DentraBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      style: IconButton.styleFrom(
        backgroundColor: AppColors.lightLavender,
        foregroundColor: AppColors.navy,
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
      ),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
    );
  }
}
