import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';

enum PasswordStrength { empty, weak, fair, strong, veryStrong }

/// Evaluates a password string and returns its [PasswordStrength].
PasswordStrength evaluatePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;

  int score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#\$&*~%^()_\-+=\[\]{}|;:,.<>?]').hasMatch(password)) {
    score++;
  }

  if (score <= 1) return PasswordStrength.weak;
  if (score == 2) return PasswordStrength.fair;
  if (score == 3) return PasswordStrength.strong;
  return PasswordStrength.veryStrong;
}

/// Visual password strength bar with label.
/// Animates segment fills as the password changes.
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final strength = evaluatePasswordStrength(password);
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();

    final (filledSegments, color, label) = _meta(strength);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (i) {
              final filled = i < filledSegments;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: filled ? color : AppColors.border,
                    borderRadius: AppRadius.smAll,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Align(
              key: ValueKey(strength),
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (int, Color, String) _meta(PasswordStrength s) {
    return switch (s) {
      PasswordStrength.weak => (1, AppColors.coral, 'Weak'),
      PasswordStrength.fair => (2, AppColors.warmOrange, 'Fair'),
      PasswordStrength.strong => (3, AppColors.successGreen, 'Strong'),
      PasswordStrength.veryStrong => (4, AppColors.primary, 'Very Strong'),
      _ => (0, AppColors.border, ''),
    };
  }
}
