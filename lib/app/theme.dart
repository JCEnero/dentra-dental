import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

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
