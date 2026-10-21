import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_glass.dart';

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.offWhite,
        colorScheme: const ColorScheme.light(
          primary: AppColors.g1,
          secondary: AppColors.g2,
          surface: AppColors.offWhite,
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        // Material's own dialogs (date pickers) can't blur what's behind
        // them, so they get a near-glass fill and the bright rim instead.
        datePickerTheme: DatePickerThemeData(
          backgroundColor: AppColors.white.withValues(alpha: 0.97),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            side: BorderSide(color: AppGlass.border, width: 1.2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.g1,
            foregroundColor: AppColors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
}
