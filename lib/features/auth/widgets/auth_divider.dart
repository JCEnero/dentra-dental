import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// A quiet "or" between sign-in options: two teal hairlines fading toward
/// the word.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    Widget line(Alignment fadeFrom) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: fadeFrom,
                end: -fadeFrom,
                colors: [
                  AppColors.g2.withValues(alpha: 0),
                  AppColors.g2.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
        );

    return Row(
      children: [
        line(Alignment.centerLeft),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryText,
            ),
          ),
        ),
        line(Alignment.centerRight),
      ],
    );
  }
}
