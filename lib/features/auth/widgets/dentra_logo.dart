import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// DENTRA brand logo.
/// On light backgrounds this is the full logo artwork (D mark + wordmark).
/// [onDark] puts the D mark on a white badge with a white wordmark, so it
/// stays legible on the teal gradient heroes.
/// [size] scales the whole component (default 1.0).
class DentraLogo extends StatelessWidget {
  final bool onDark;
  final double size;

  const DentraLogo({
    super.key,
    this.onDark = false,
    this.size = 1.0,
  });

  static const String markAsset = 'assets/images/dentra_mark.png';
  static const String fullAsset = 'assets/images/dentra_logo.png';

  @override
  Widget build(BuildContext context) {
    if (!onDark) {
      return Image.asset(
        fullAsset,
        height: 34 * size,
        fit: BoxFit.contain,
        semanticLabel: 'Dentra',
      );
    }

    final badgeSize = 30.0 * size;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // D mark badge
        Container(
          width: badgeSize,
          height: badgeSize,
          padding: EdgeInsets.all(badgeSize * 0.16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8 * size),
          ),
          child: Image.asset(markAsset, fit: BoxFit.contain),
        ),
        SizedBox(width: 10 * size),
        // Wordmark, letter-spaced to echo the logo artwork
        Text(
          'DENTRA',
          style: GoogleFonts.outfit(
            fontSize: 21.0 * size,
            fontWeight: FontWeight.w500,
            color: AppColors.white,
            letterSpacing: 4.0 * size,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
