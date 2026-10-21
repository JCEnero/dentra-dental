import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dental_records/widgets/record_source_label.dart';
import '../../scan/data/scan_regions.dart';
import '../../screening/data/models/screening_session.dart';

/// One screening in the history list. The whole card opens the details.
class ScreeningHistoryCard extends StatelessWidget {
  const ScreeningHistoryCard({
    super.key,
    required this.session,
    required this.isLatest,
    required this.alternate,
    required this.onTap,
  });

  final ScreeningSession session;

  /// The newest screening overall; labelled "Latest" instead of "View".
  final bool isLatest;

  /// Alternates the teal rim shade, as in the original design.
  final bool alternate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rim = alternate ? AppColors.cardSolid : AppColors.g2;
    final at = session.completedAt;
    final captured = session.capturedRegions.length;
    final regionNames = session.capturedRegions
        .map((id) => scanRegions.where((r) => r.id == id).firstOrNull?.label)
        .whereType<String>()
        .join(', ');
    final complete = session.isComplete;
    final statusColor = complete ? AppColors.successGreen : AppColors.warmOrange;

    return Semantics(
      button: true,
      label: '${RecordSource.aiScreening.label}. '
          '${isLatest ? 'Latest screening' : 'Screening'}, '
          '${DentraDates.full(at)} at ${DentraDates.time(at)}. '
          '${session.status.label}, $captured of ${session.totalRegions} '
          'regions captured. Opens details.',
      excludeSemantics: true,
      child: GlassCard(
        borderColor: rim.withValues(alpha: 0.55),
        borderWidth: 1.5,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RecordSourceLabel(source: RecordSource.aiScreening),
                  const SizedBox(height: 8),
                  Text(
                    '${DentraDates.long(at)} · ${DentraDates.time(at)}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dental Screening',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // One ring per captured image, as in the original.
                      SizedBox(
                        width: 22.0 + 16.0 * (captured.clamp(1, 5) - 1),
                        height: 22,
                        child: Stack(
                          children: [
                            for (var j = 0; j < captured.clamp(0, 5); j++)
                              Positioned(
                                left: 16.0 * j,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.g2
                                        .withValues(alpha: 0.18 - j * 0.025),
                                    border: Border.all(
                                      color: AppColors.g2.withValues(alpha: 0.35),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '$captured ${captured == 1 ? 'image' : 'images'} · '
                          '$captured of ${session.totalRegions} regions',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.navy.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (regionNames.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      regionNames,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.navy.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.g2.withValues(alpha: isLatest ? 0.9 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isLatest ? 'Latest' : 'View',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isLatest ? AppColors.white : AppColors.g2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      session.status.label,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.g2.withValues(alpha: 0.8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder cards shown while history loads.
class ScreeningCardSkeleton extends StatelessWidget {
  const ScreeningCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.g2.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return ExcludeSemantics(
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(140, 10),
            const SizedBox(height: 10),
            bar(160, 14),
            const SizedBox(height: 12),
            bar(200, 10),
          ],
        ),
      ),
    );
  }
}

/// Centered message with an icon and up to two actions.
class HistoryMessage extends StatelessWidget {
  const HistoryMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.g2;
    return Semantics(
      liveRegion: true,
      child: GlassCard(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.secondaryText,
                height: 1.45,
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                actions[i],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
