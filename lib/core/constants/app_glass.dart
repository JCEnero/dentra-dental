import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Glass surface tokens: translucent white over the ambient backdrop.
///
/// Everything here is derived from the existing palette (white, teal),
/// only with transparency, so glass cards stay on-brand.
abstract class AppGlass {
  /// Background blur behind glass surfaces. Kept moderate so text on
  /// top stays crisp and the effect stays cheap.
  static const double blurSigma = 18;
  static final ImageFilter blur =
      ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);

  // ── Fills (white at different strengths) ──────────────────────
  static const Color fillHigh = Color(0xA8FFFFFF); // 66%
  static const Color fillLow = Color(0x70FFFFFF); // 44%

  /// Bars (bottom nav, action bars) stay a little more opaque so
  /// controls read clearly.
  static const Color barFill = Color(0xC7FFFFFF); // 78%

  // ── Strokes ───────────────────────────────────────────────────
  /// Bright rim that catches the light, like a glass edge.
  static const Color border = Color(0xBFFFFFFF); // 75%

  /// Hairline divider that works on tinted backgrounds, where the
  /// grey `AppColors.border` would look muddy.
  static final Color divider = AppColors.g2.withValues(alpha: 0.12);

  /// Translucent fill with a soft top-left sheen.
  static BoxDecoration surface({
    required BorderRadius borderRadius,
    Color tint = AppColors.white,
    Color? borderColor,
    double borderWidth = 1,
  }) {
    return BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tint.withValues(alpha: fillHigh.a),
          tint.withValues(alpha: fillLow.a),
        ],
      ),
      border: Border.all(color: borderColor ?? border, width: borderWidth),
    );
  }
}
