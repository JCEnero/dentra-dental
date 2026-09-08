import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// DENTRA typography — uses Outfit (primary) matching the web frontend.
abstract class AppTypography {
  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: AppColors.white,
        letterSpacing: -0.5,
        height: 1.15,
      );

  static TextStyle get headingXL => GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.white,
        letterSpacing: -0.5,
        height: 1.15,
      );

  static TextStyle get headingLg => GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.white,
        letterSpacing: -0.3,
      );

  static TextStyle get headingMd => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      );

  static TextStyle get headingSm => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      );

  static TextStyle get bodyLg => GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.navy,
        height: 1.5,
      );

  static TextStyle get bodyMd => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.navy,
        height: 1.5,
      );

  static TextStyle get bodySm => GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.secondaryText,
        height: 1.5,
      );

  static TextStyle get caption => GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.secondaryText,
        letterSpacing: 0.8,
      );

  static TextStyle get overline => GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.secondaryText,
        letterSpacing: 1.2,
      );

  static TextStyle get label => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.secondaryText,
      );

  static TextStyle get buttonPrimary => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.white,
        letterSpacing: 0.1,
      );

  static TextStyle get buttonSecondary => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.secondaryText,
      );

  // ── On-gradient variants ───────────────────────────────────────
  static TextStyle get captionOnGradient => overline.copyWith(
        color: Colors.white.withValues(alpha: 0.45),
      );

  static TextStyle get bodyOnGradient => bodySm.copyWith(
        color: Colors.white.withValues(alpha: 0.55),
      );

  static TextStyle get metricValue => GoogleFonts.outfit(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: AppColors.white,
        height: 1.0,
      );
}
