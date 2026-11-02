import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_report.dart';
import '../scan_theme.dart';
import 'report_style.dart';

/// The headline: the result in a few words, one plain sentence, and when to
/// see a dentist. Everything else is further down, for those who want it.
class ReportHero extends StatelessWidget {
  const ReportHero({
    super.key,
    required this.report,
    required this.status,
    required this.date,
    required this.viewsTaken,
    required this.leading,
  });

  final ScreeningReport report;

  /// How the scan went, e.g. "Scan complete".
  final String status;
  final String date;
  final int viewsTaken;

  /// The mark beside [status].
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(status, style: reportCardTitle),
                    ),
                    Text(
                      '$date · $viewsTaken of ${scanRegions.length} views',
                      style: reportNote,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(report.headline, style: reportHeadline),
          ),
          const SizedBox(height: 6),
          Text(report.sentence, style: reportBody),
          if (report.photosRead > 0) ...[
            const SizedBox(height: 16),
            _CareScale(level: report.level),
          ],
        ],
      ),
    );
  }
}

/// Four short steps, filled in teal up to the result's own, and its name in
/// words, so where it sits reads without colour too.
class _CareScale extends StatelessWidget {
  const _CareScale({required this.level});

  final ReportLevel level;

  String get _label => switch (level) {
        ReportLevel.none => 'Nothing to do now',
        ReportLevel.nextVisit => 'At your next check-up',
        ReportLevel.soon => 'Book soon',
        ReportLevel.prompt => 'See one promptly',
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'When to see a dentist: $_label, '
          'step ${level.index + 1} of ${ReportLevel.values.length}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final l in ReportLevel.values) ...[
                if (l != ReportLevel.none) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: l.index <= level.index
                          ? AppColors.primary
                          : AppColors.g2.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              Text('When to see a dentist', style: reportNote),
              Text(
                _label,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ScanColors.clearInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
