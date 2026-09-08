import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final double size;
  final String initials;

  const AvatarWidget({
    super.key,
    this.size = 36,
    this.initials = 'RJ',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}
