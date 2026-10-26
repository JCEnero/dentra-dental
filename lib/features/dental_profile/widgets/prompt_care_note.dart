import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';

/// Advice to seek professional care, shown whenever the user reports
/// severe discomfort. It stands on its own: no screening result, however
/// reassuring, hides or softens it.
class PromptCareNote extends StatelessWidget {
  const PromptCareNote({super.key});

  static const title = 'Severe discomfort needs prompt attention';
  static const message =
      'Please contact a dentist as soon as you can. If you have facial '
      'swelling, a fever, or trouble swallowing or breathing, get '
      'emergency care right away.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.1),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.medical_services_outlined,
              size: 20,
              color: AppColors.danger,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.navy,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
