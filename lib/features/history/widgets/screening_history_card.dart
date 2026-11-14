import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../scan/data/scan_report.dart';
import '../../scan/widgets/scan_theme.dart' show ScanColors;
import '../../screening/data/models/screening_session.dart';

/// The scan's result in a few words, once its analysis has really read something.
String? _resultOf(ScreeningSession session) {
  final analysis = session.analysis;
  if (analysis == null || analysis.status != AnalysisStatus.complete) {
    return null;
  }
  final report = ScreeningReport(analysis, session.capturedRegions);
  if (report.detectorOff || report.photosRead == 0) return null;
  return report.headline;
}

/// One screening in the history list: what it was, when, what it found and
/// how much was captured. Photos stay on the details page. The whole card
/// opens the details.
class ScreeningHistoryCard extends StatelessWidget {
  const ScreeningHistoryCard({
    super.key,
    required this.session,
    required this.isLatest,
    required this.alternate,
    required this.onTap,
  });

  final ScreeningSession session;

  /// The newest screening overall; gets a small "Latest" mark.
  final bool isLatest;

  /// Alternates the teal rim shade.
  final bool alternate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rim = alternate ? AppColors.cardSolid : AppColors.g2;
    final at = session.completedAt;
    final captured = session.capturedViewCount;
    final complete = session.isComplete;
    final result = _resultOf(session);
    final muted = AppColors.navy.withValues(alpha: 0.55);

    return Semantics(
      button: true,
      label: '${isLatest ? 'Latest dental screening' : 'Dental screening'}, '
          '${DentraDates.full(at)} at ${DentraDates.time(at)}. '
          '${session.status.label}, $captured of ${session.totalRegions} '
          'views captured.${result == null ? '' : ' $result.'} Opens details.',
      excludeSemantics: true,
      child: GlassCard(
        borderColor: rim.withValues(alpha: 0.45),
        borderWidth: 1.2,
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dental Screening',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                if (isLatest)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.g2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Latest',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.g2,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${DentraDates.long(at)} · ${DentraDates.time(at)}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text(
                result,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ScanColors.clearInk,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: complete
                        ? AppColors.successGreen
                        : AppColors.warmOrange,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${session.status.label} · '
                    '$captured of ${session.totalRegions} views',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.g2.withValues(alpha: 0.85),
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
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(150, 14),
            const SizedBox(height: 8),
            bar(120, 10),
            const SizedBox(height: 14),
            bar(170, 10),
          ],
        ),
      ),
    );
  }
}

/// Centered message with an icon and up to two actions. For the pages'
/// first-time and couldn't-load states, pass [mascot] and Rabi stands in
/// for the icon.
class HistoryMessage extends StatelessWidget {
  const HistoryMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
    this.danger = false,
    this.mascot,
  });

  final IconData icon;

  /// Rabi in this mood, in place of [icon].
  final MascotMood? mascot;
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
            if (mascot != null) ...[
              DentraMascot(mood: mascot!, size: 104, stage: true),
              const SizedBox(height: 10),
            ] else ...[
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
            ],
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
