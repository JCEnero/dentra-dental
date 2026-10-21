import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/tooth_catalog.dart';

/// Tooth-type colours for the legend, chart and "colour by type" mode:
/// one teal-to-navy ramp from the brand palette, light at the front of
/// the mouth and deepest at the back.
abstract class ToothTypeColors {
  static final Color _deepTeal =
      Color.lerp(AppColors.g2, AppColors.navy, 0.45)!;

  static Color of(ToothType type) => switch (type) {
        ToothType.incisor => AppColors.g1,
        ToothType.canine => AppColors.g2,
        ToothType.premolar => _deepTeal,
        ToothType.molar => AppColors.navy,
      };
}
