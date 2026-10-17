import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/glass_card.dart';

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

/// Up to two initials from the clinic name, skipping words like "Dental".
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

/// Icon that best matches a service name.
IconData serviceIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('consult')) return Icons.forum_rounded;
  if (n.contains('clean')) return Icons.cleaning_services_rounded;
  if (n.contains('filling')) return Icons.healing_rounded;
  if (n.contains('extract')) return Icons.content_cut_rounded;
  if (n.contains('whiten')) return Icons.auto_awesome_rounded;
  if (n.contains('root')) return Icons.biotech_rounded;
  if (n.contains('x-ray') || n.contains('xray')) {
    return Icons.document_scanner_rounded;
  }
  if (n.contains('crown') || n.contains('cap')) {
    return Icons.workspace_premium_rounded;
  }
  if (n.contains('brace')) return Icons.straighten_rounded;
  return Icons.medical_services_rounded;
}

/// Frosted tile with the clinic's initials, used as its "logo".
class ClinicAvatar extends StatelessWidget {
  const ClinicAvatar({super.key, required this.name, this.size = 52});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.3);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radius,
        child: GlassBlur(
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.white.withValues(alpha: 0.9),
                  AppColors.mintGreen.withValues(alpha: 0.75),
                ],
              ),
              border: Border.all(color: AppGlass.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.g2.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              clinicInitials(name),
              style: GoogleFonts.outfit(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
                color: AppColors.g2,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round frosted icon button for headers and top bars.
class ClinicGlassIconButton extends StatelessWidget {
  const ClinicGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.badgeCount = 0,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Filled teal, e.g. when filters are applied.
  final bool active;
  final int badgeCount;

  /// Shows a spinner in place of the icon.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppColors.white : AppColors.navy;
    return IconButton(
      onPressed: busy ? null : onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor:
            active ? AppColors.g2 : AppColors.white.withValues(alpha: 0.7),
        disabledBackgroundColor: AppColors.white.withValues(alpha: 0.7),
        foregroundColor: foreground,
        side: BorderSide(color: active ? AppColors.g2 : AppGlass.border),
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
          : Badge(
              isLabelVisible: badgeCount > 0,
              backgroundColor: AppColors.coral,
              label: Text('$badgeCount'),
              child: Icon(icon, size: 20),
            ),
    );
  }
}

/// Five small stars for a 0–5 rating, with half stars.
class ClinicStars extends StatelessWidget {
  const ClinicStars({super.key, required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final fill = (rating - i).clamp(0.0, 1.0);
          final icon = fill >= 0.75
              ? Icons.star_rounded
              : fill >= 0.25
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded;
          return Icon(
            icon,
            size: size,
            color: fill >= 0.25
                ? AppColors.warmOrange
                : AppColors.secondaryText.withValues(alpha: 0.4),
          );
        }),
      ),
    );
  }
}
