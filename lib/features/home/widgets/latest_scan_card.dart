import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../history/screens/screening_detail_screen.dart';
import '../../scan/data/scan_outcomes.dart';
import '../../scan/data/scan_report.dart';
import '../../scan/widgets/report/mouth_3d.dart';
import '../../scan/widgets/report/report_style.dart';
import '../../scan/widgets/scan_theme.dart';
import '../../scan/widgets/visuals/dental_arch_painter.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';

/// Where things stood at the last scan, a glance from Home: the mouth map and
/// the result in a few words. Takes no space until a scan has really been read.
class LatestScanCard extends ConsumerWidget {
  const LatestScanCard({super.key});

  /// After this long, the card also suggests scanning again.
  static const _dueAfter = Duration(days: 30);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(screeningSessionsProvider).valueOrNull ??
        const <ScreeningSession>[];
    final trend = ScanTrend.of(sessions);
    if (trend.points.isEmpty) return const SizedBox.shrink();
    final latest = trend.points.last;
    final report = latest.report;
    final due = DateTime.now().difference(latest.at) >= _dueAfter;
    final signs = report.signCount, faint = report.faintCount;
    final detail = [
      if (signs > 0) '$signs ${signs == 1 ? 'sign' : 'signs'}',
      if (faint > 0) '$faint faint',
      DentraDates.relative(latest.at),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: 'Latest scan: ${report.headline}. $detail.'
            '${due ? ' Time to scan again.' : ''} Opens details.',
        excludeSemantics: true,
        child: GlassCard(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          onTap: () => Navigator.of(context)
              .push(ScreeningDetailScreen.route(latest.sessionId)),
          child: Row(
            children: [
              SizedBox(
                width: 66,
                child: AspectRatio(
                  aspectRatio: kMouthMapCanvas.aspectRatio,
                  child: CustomPaint(
                    painter: MouthMapPainter({
                      for (final a in MouthArea.values)
                        a: mouthMapStyle(report.areas[a]!.state),
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LATEST SCAN', style: capsLabel()),
                    const SizedBox(height: 3),
                    Text(
                      report.headline,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(detail, style: reportNote),
                    if (due) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Time to scan again and see what changed.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ScanColors.clearInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.g2),
            ],
          ),
        ),
      ),
    );
  }
}
