import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// Heavier blur for surfaces that appear over content (dialogs,
  /// sheets, snackbars), so text behind them dissolves instead of
  /// showing through.
  static const double floatBlurSigma = 32;
  static final ImageFilter floatBlur =
      ImageFilter.blur(sigmaX: floatBlurSigma, sigmaY: floatBlurSigma);

  // ── Fills (white at different strengths) ──────────────────────
  static const Color fillHigh = Color(0xA8FFFFFF); // 66%
  static const Color fillLow = Color(0x70FFFFFF); // 44%

  /// Bars (bottom nav, action bars) stay a little more opaque so
  /// controls read clearly.
  static const Color barFill = Color(0xC7FFFFFF); // 78%

  /// Surfaces that appear over the page (dialogs, sheets, snackbars).
  /// A little denser than page cards, since they sit on a dimmed page,
  /// but still see-through like Home.
  ///
  /// The web build skips backdrop blur (see `GlassBlur`), so there these
  /// are nearly opaque; otherwise nothing would hide the text behind.
  static Color get floatHigh =>
      kIsWeb ? const Color(0xF5FFFFFF) : const Color(0xDBFFFFFF); // 96% / 86%
  static Color get floatLow =>
      kIsWeb ? const Color(0xEBFFFFFF) : const Color(0xBDFFFFFF); // 92% / 74%

  /// Dims the page behind dialogs and sheets, lightly enough that the
  /// glass still shows what's behind it.
  static final Color barrier = AppColors.navy.withValues(alpha: 0.26);

  // ── Strokes ───────────────────────────────────────────────────
  /// Bright rim that catches the light, like a glass edge.
  static const Color border = Color(0xBFFFFFFF); // 75%

  /// Hairline divider that works on tinted backgrounds, where the
  /// grey `AppColors.border` would look muddy.
  static final Color divider = AppColors.g2.withValues(alpha: 0.12);

  /// Glass for surfaces that appear over the page: translucent white
  /// with a faint mint fade and a bright rim.
  static BoxDecoration floating({
    required BorderRadius borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          floatHigh,
          AppColors.lightLavender.withValues(alpha: floatLow.a)
        ],
      ),
      border: border ?? Border.all(color: AppGlass.border, width: 1.2),
    );
  }

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
