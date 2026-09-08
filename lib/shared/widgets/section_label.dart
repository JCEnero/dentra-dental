import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Uppercase section label — used on gradient backgrounds.
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const SectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: color ?? Colors.white.withValues(alpha: 0.45),
      ),
    );
  }
}
