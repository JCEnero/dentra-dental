import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_report.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import 'mouth_3d.dart';
import 'report_charts.dart';
import 'report_motion.dart';
import 'report_style.dart';

/// The top of the page: the 3D mouth floating above a glass card that holds the
/// result, when to see a dentist, and three figures. All of it fits one glance.
class ReportHero extends StatefulWidget {
  const ReportHero({
    super.key,
    required this.report,
    required this.status,
    required this.date,
    required this.viewsTaken,
    required this.leading,
    required this.focus,
    required this.onSeeSpot,
  });

  final ScreeningReport report;

  /// How the scan went, e.g. "Scan complete".
  final String status;
  final String date;
  final int viewsTaken;

  /// The mark beside [status].
  final Widget leading;

  /// The sign the mouth is showing, or null for the whole mouth.
  final ValueNotifier<ReportSpot?> focus;
  final ValueChanged<ReportSpot> onSeeSpot;

  @override
  State<ReportHero> createState() => _ReportHeroState();
}

class _ReportHeroState extends State<ReportHero> {
  /// An area tapped on the model that has nothing to show.
  MouthArea? _tapped;

  void _onAreaTap(MouthArea area) {
    final spots = widget.report.areas[area]!.spots;
    if (spots.isEmpty) {
      setState(() => _tapped = area);
      return;
    }
    setState(() => _tapped = null);
    widget.onSeeSpot(spots.first);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final read = report.photosRead > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (read)
          SizedBox(
            height: 250,
            child: Semantics(
              label: 'Model of a mouth. ${_areasInWords(report)}',
              child: Mouth3D(
                report: report,
                focus: widget.focus,
                onAreaTap: _onAreaTap,
              ),
            ),
          ),
        if (read)
          _ModelCaption(
            focus: widget.focus,
            tapped: _tapped,
            report: report,
            onShowAll: () {
              setState(() => _tapped = null);
              widget.focus.value = null;
            },
          ),
        if (read) const SizedBox(height: 10),
        GlassCard(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  widget.leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          liveRegion: true,
                          child: Text(widget.status, style: reportCardTitle),
                        ),
                        Text(
                          '${widget.date} · ${widget.viewsTaken} of '
                          '${scanRegions.length} views',
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
              if (read) ...[
                const SizedBox(height: 16),
                _CareScale(level: report.level),
                const SizedBox(height: 18),
                _Figures(report: report),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _areasInWords(ScreeningReport report) {
    final flagged = [
      for (final a in report.areas.values)
        if (a.state.flagged) '${a.area.label}: ${areaStateLabel(a.state)}',
    ];
    return flagged.isEmpty ? 'No area is flagged.' : '${flagged.join('. ')}.';
  }
}

/// One line under the model: what it's showing, and how to get back.
class _ModelCaption extends StatelessWidget {
  const _ModelCaption({
    required this.focus,
    required this.tapped,
    required this.report,
    required this.onShowAll,
  });

  final ValueListenable<ReportSpot?> focus;
  final MouthArea? tapped;
  final ScreeningReport report;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReportSpot?>(
      valueListenable: focus,
      builder: (context, spot, _) {
        final area = tapped;
        final String text;
        if (spot != null) {
          text = spot.where;
        } else if (area != null) {
          text = '${area.label}: '
              '${areaStateLabel(report.areas[area]!.state).toLowerCase()}';
        } else {
          text = 'General model. Drag to turn, tap a teal area.';
        }
        return AnimatedSwitcher(
          duration: ScanMotion.of(context, ScanMotion.fast),
          child: Row(
            key: ValueKey('$text${spot == null}'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: spot == null && area == null
                      ? reportNote
                      : reportCardTitle,
                ),
              ),
              if (spot != null)
                TextButton(
                  onPressed: onShowAll,
                  style: TextButton.styleFrom(
                    foregroundColor: ScanColors.clearInk,
                    minimumSize: const Size(44, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Whole mouth'),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Four steps filling up in teal to the result's own, with its name in words,
/// so where it sits reads without colour too.
class _CareScale extends StatelessWidget {
  const _CareScale({required this.level});

  final ReportLevel level;

  String get _label => switch (level) {
        ReportLevel.none => 'Your regular check-ups',
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
          InViewAnimation(
            builder: (context, t) => Row(
              children: [
                for (final l in ReportLevel.values) ...[
                  if (l != ReportLevel.none) const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 5,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: AppColors.g2.withValues(alpha: 0.14),
                            ),
                            if (l.index <= level.index)
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _fill(l, t),
                                child: const ColoredBox(
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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

  /// The steps fill one after another, left to right.
  double _fill(ReportLevel l, double t) {
    final steps = level.index + 1;
    return (t * steps - l.index).clamp(0.0, 1.0);
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.report});

  final ScreeningReport report;

  @override
  Widget build(BuildContext context) {
    final surfaces = report.surfaces;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RingMeter(
            value: report.areasFlagged,
            total: MouthArea.values.length,
            label: 'areas flagged',
          ),
        ),
        Expanded(
          child: surfaces == null
              ? RingMeter(
                  value: report.areasRead,
                  total: MouthArea.values.length,
                  label: 'areas read',
                )
              : RingMeter(
                  value: surfaces.fold<int>(0, (sum, s) => sum + s.$2),
                  total: surfaces.length * MouthArea.values.length,
                  label: 'surfaces read',
                ),
        ),
        Expanded(
          child: RingMeter(
            value: report.photosRead,
            total: report.photoIds.length,
            label: 'photos read',
          ),
        ),
      ],
    );
  }
}
