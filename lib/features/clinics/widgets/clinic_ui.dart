import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';

// Small pieces shared by the clinic list and clinic detail screens.

/// "850 m" under a kilometer, "2.7 km" above.
String formatClinicDistance(double? km) {
  if (km == null) return '--';
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

/// Peso amount with thousands separators, e.g. ₱8,000.
String formatPeso(double amount) {
  final digits = amount.round().toString();
  final buffer = StringBuffer('₱');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Up to two initials from the clinic name, skipping words like "Dental",
/// e.g. "Urban Smiles Dental Clinic" → "US".
String clinicInitials(String name) {
  const skip = {'dental', 'clinic', 'center', 'centre', 'the', 'and', 'of'};
  final words = name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]))
      .toList();
  final meaningful =
      words.where((w) => !skip.contains(w.toLowerCase())).toList();
  final source = meaningful.isNotEmpty ? meaningful : words;
  if (source.isEmpty) return '+';
  return source.take(2).map((w) => w[0].toUpperCase()).join();
}

/// Round frosted icon button for headers and top bars.
class ClinicGlassIconButton extends StatelessWidget {
  const ClinicGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// A quiet teal tint and rim, e.g. when filters are applied. No badge:
  /// a count reads like an unread notification.
  final bool active;

  /// Shows a spinner in place of the icon.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: busy ? null : onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? AppColors.lightLavender.withValues(alpha: 0.85)
            : AppColors.white.withValues(alpha: 0.7),
        disabledBackgroundColor: AppColors.white.withValues(alpha: 0.7),
        foregroundColor: active ? AppColors.g2 : AppColors.navy,
        side: BorderSide(
          color: active ? AppColors.g2.withValues(alpha: 0.4) : AppGlass.border,
        ),
        fixedSize: const Size(48, 48),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.g2,
              ),
            )
          : Icon(icon, size: 20),
    );
  }
}
