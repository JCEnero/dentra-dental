import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/dentra_dates.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_report.dart';
import '../scan_theme.dart';
import 'report_charts.dart';
import 'report_style.dart';

/// How this scan compares with the ones before: signs per scan as a line, and
/// how many areas are new, still flagged or gone. Light and angle change between
/// scans, so it leans on what keeps showing up rather than any one change.
class TrendSection extends StatefulWidget {
  const TrendSection({super.key, required this.trend});

  final ScanTrend trend;

  @override
  State<TrendSection> createState() => _TrendSectionState();
}

class _TrendSectionState extends State<TrendSection> {
  /// The tapped scan; the latest until then.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final trend = widget.trend;
    if (!trend.hasHistory) return const _Baseline();
    final points = trend.points;
    final selected =
        (_selected ?? points.length - 1).clamp(0, points.length - 1);
    final shown = points[selected];
    final repeating = trend.repeating.keys;
    return GlassCard(
      width: double.infinity,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Change(
                  value: trend.newAreas.length,
                  label: 'new',
                  areas: trend.newAreas,
                ),
              ),
              Expanded(
                child: _Change(
                  value: trend.stillAreas.length,
                  label: 'still flagged',
                  areas: trend.stillAreas,
                ),
              ),
              Expanded(
                child: _Change(
                  value: trend.clearedAreas.length,
                  label: 'gone',
                  areas: trend.clearedAreas,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Areas, since your last scan', style: reportNote),
          const SizedBox(height: 12),
          TrendChart(
            values: [for (final p in points) p.report.signCount],
            selected: selected,
            onSelect: (i) => setState(() => _selected = i),
            describe: (i) => _describe(points[i]),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_short(points.first.at), style: reportNote),
              Text(_short(points.last.at), style: reportNote),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _describe(shown),
            style: figureText(size: 12.5, weight: FontWeight.w600),
          ),
          if (repeating.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Signs keep showing up in: '
              '${describeAreas(repeating.toSet()).toLowerCase()}. That\'s worth '
              'showing a dentist, even if they look faint.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: ScanColors.clearInk,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            trend.mixedVersions
                ? 'Older scans used an earlier version of this check, so some '
                    'change may come from the check, not your teeth.'
                : 'Light and angle change between scans. What keeps showing up '
                    'matters more than one small change.',
            style: reportNote,
          ),
        ],
      ),
    );
  }

  static String _short(DateTime d) =>
      '${DentraDates.monthShort(d.month)} ${d.day}';

  static String _describe(TrendPoint p) {
    final r = p.report;
    final signs = r.signCount, faint = r.faintCount;
    return [
      DentraDates.medium(p.at),
      '$signs ${signs == 1 ? 'sign' : 'signs'}',
      if (faint > 0) '$faint faint',
    ].join(' · ');
  }
}

class _Change extends StatelessWidget {
  const _Change({
    required this.value,
    required this.label,
    required this.areas,
  });

  final int value;
  final String label;
  final List<MouthArea> areas;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label'
          '${areas.isEmpty ? '' : ': ${areas.map((a) => a.label).join(', ')}'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: GoogleFonts.outfit(
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: value > 0 ? ScanColors.clearInk : AppColors.secondaryText,
            ),
          ),
          Text(label, style: reportNote),
        ],
      ),
    );
  }
}

/// The first scan: nothing to compare with yet, and that's the message.
class _Baseline extends StatelessWidget {
  const _Baseline();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 40,
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final (i, h) in const [12.0, 20.0, 28.0, 38.0].indexed)
                    Container(
                      width: 10,
                      height: h,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? AppColors.primary
                            : AppColors.g2.withValues(alpha: 0.13),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This is your starting point', style: reportCardTitle),
                const SizedBox(height: 2),
                Text(
                  'Scan again in a few weeks and this will show what changed.',
                  style: reportBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
