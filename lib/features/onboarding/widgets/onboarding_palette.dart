import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Onboarding colours, taken from the Home tab's palette: the bright
/// cyan-mint → medium teal of `AppColors.cardGradient` / `primaryGradient`,
/// with mint and white. Nothing is darker than `AppColors.g2`, the base of
/// the Home hero card.
abstract class OnboardingPalette {
  /// Brightest stop of the Home hero card gradient (#5DE0D0).
  static final Color highlight = AppColors.cardGradient.colors.first;

  /// Bright cyan-mint (#4DD8C8), the light end of the brand gradient.
  static const Color mint = AppColors.g1;

  /// Mid turquoise (#3BBFB8).
  static const Color turquoise = AppColors.cardSolid;

  /// Medium teal (#2CA6A4): the darkest tone used, as on the Home card.
  static const Color base = AppColors.g2;

  /// Tint for soft shadows (always used with transparency).
  static const Color shadow = AppColors.g2;

  /// Pale mint glow and shading for the white forms.
  static const Color glow = AppColors.mintGreen;
  static const Color mist = AppColors.lightLavender;
}
