import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Small meta chip used to display secondary information like category,
/// duration, distance, rating, etc.
///
/// Displays an optional icon followed by a label in a rounded container
/// with a semi-transparent background color.
class DentraMetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const DentraMetaChip({
    super.key,
    required this.label,
    this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
