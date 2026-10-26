import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'glass_card.dart';

/// Informational note card with an icon and message.
///
/// Used to display disclaimers, tips, or important information in a
/// visually distinct container.
class DentraNoteCard extends StatelessWidget {
  final String message;
  final IconData icon;

  const DentraNoteCard({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: AppColors.lightLavender,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.g2,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.navy,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
