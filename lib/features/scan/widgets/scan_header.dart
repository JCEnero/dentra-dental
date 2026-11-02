import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../data/scan_regions.dart';
import 'scan_motion.dart';

/// Title plus session progress, derived only from accepted captures.
class ScanHeader extends StatelessWidget {
  const ScanHeader({
    super.key,
    required this.capturedIds,
    required this.selectedId,
    required this.showProgress,
    this.onStartOver,
    this.onBack,
  });

  final Set<String> capturedIds;
  final String? selectedId;
  final bool showProgress;

  /// Shown once there is progress worth confirming before discarding.
  final VoidCallback? onStartOver;

  /// Returns to the previous page; hidden when null.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final done = scanRegions.where((r) => capturedIds.contains(r.id)).length;
    final total = scanRegions.length;
    final duration = ScanMotion.of(context, ScanMotion.medium);

    return DentraPageHeader(
      title: 'Dental Scan',
      onBack: onBack,
      trailing: onStartOver == null
          ? null
          : TextButton(
              onPressed: onStartOver,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryText,
                minimumSize: const Size(48, 44),
                textStyle: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Start over'),
            ),
      bottom: !showProgress
          ? null
          : Semantics(
              label: '$done of $total views captured',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < total; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedContainer(
                            duration: duration,
                            curve: ScanMotion.curve,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: capturedIds.contains(scanRegions[i].id)
                                  ? AppColors.primaryGradient
                                  : null,
                              color: capturedIds.contains(scanRegions[i].id)
                                  ? null
                                  : selectedId != null && baseRegionId(selectedId!) == scanRegions[i].id
                                      ? AppColors.lavender
                                      : AppColors.border,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    done == total
                        ? 'All $total views captured'
                        : '$done of $total views captured',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: done == total
                          ? AppColors.primary
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
