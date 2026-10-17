import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final double size;
  final String initials;

  /// Raw bytes — works on all platforms (web, Android, iOS).
  final Uint8List? imageBytes;

  /// File fallback for native-only paths (kept for compatibility).
  final File? imageFile;

  const AvatarWidget({
    super.key,
    this.size = 36,
    this.initials = 'RJ',
    this.imageBytes,
    this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;

    if (imageBytes != null) {
      provider = MemoryImage(imageBytes!);
    } else if (imageFile != null && !kIsWeb) {
      provider = FileImage(imageFile!);
    }

    if (provider != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: provider,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Fallback: gradient with initials
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
