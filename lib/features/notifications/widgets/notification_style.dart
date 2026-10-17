import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/models/app_notification.dart';

/// Icon and accent per category, shared by the list and the detail sheet.
/// Accents stay within the brand palette and are only used as soft tints.
extension NotificationCategoryStyle on NotificationCategory {
  IconData get icon => switch (this) {
        NotificationCategory.screening => Icons.photo_camera_outlined,
        NotificationCategory.account => Icons.person_outline_rounded,
        NotificationCategory.security => Icons.shield_outlined,
        NotificationCategory.system => Icons.campaign_outlined,
      };

  Color get accent => switch (this) {
        NotificationCategory.screening => AppColors.g2,
        NotificationCategory.account => AppColors.navy,
        NotificationCategory.security => AppColors.coral,
        NotificationCategory.system => AppColors.g2,
      };
}

extension NotificationTargetLabel on NotificationTarget {
  /// Label for the button that opens the target, or null when none.
  String? get actionLabel => switch (this) {
        NotificationTarget.none => null,
        NotificationTarget.screening => 'View screening',
        NotificationTarget.profile => 'Open account settings',
      };
}
