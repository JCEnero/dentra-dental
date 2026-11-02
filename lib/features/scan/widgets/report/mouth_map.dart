import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_report.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import '../visuals/dental_arch_painter.dart';
import 'report_style.dart';

/// How an area's teeth are drawn on the map, wherever the map is shown.
MouthMapStyle mouthMapStyle(AreaState state, {bool selected = false}) =>
    switch (state) {
      AreaState.strong || AreaState.possible || AreaState.faint => MouthMapStyle(
          fill: ReportColors.of(state),
          outline: AppColors.white,
          selected: selected,
        ),
      AreaState.clear => MouthMapStyle(
          fill: ReportColors.clear,
          outline: AppColors.g2.withValues(alpha: 0.5),
          selected: selected,
        ),
      _ => MouthMapStyle(
          fill: ReportColors.hollow,
          outline: ReportColors.hollowEdge,
          selected: selected,
        ),
    };

/// The mouth as a chart of six general areas, each coloured by what the scan
/// said about it. Tap an area for what's behind its colour. The teeth drawn are
/// a general mouth rather than this person's, so nothing here reads as a claim
/// about one tooth: the marked photos below do that.
class MouthMap extends StatefulWidget {
  const MouthMap({super.key, required this.report, required this.onSeeSpot});

  final ScreeningReport report;

  /// Asks to show this spot in its photo.
  final ValueChanged<ReportSpot> onSeeSpot;

  @override
  State<MouthMap> createState() => _MouthMapState();
}

class _MouthMapState extends State<MouthMap> {
  /// Starts on the most pressing area, if any is flagged.
  late MouthArea? _selected = _mostPressing();

  MouthArea? _mostPressing() {
    AreaReport? top;
    for (final a in widget.report.areas.values) {
      if (a.state.flagged && (top == null || a.state.index > top.state.index)) {
        top = a;
      }
    }
    return top?.area;
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.report.areas;
    final shown = {for (final a in areas.values) a.state};
    final selected = _selected;
    return GlassCard(
      width: double.infinity,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: AspectRatio(
                aspectRatio: kMouthMapCanvas.aspectRatio,
                child: LayoutBuilder(builder: (context, c) {
                  final scale = c.maxWidth / kMouthMapCanvas.width;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: MouthMapPainter({
                              for (final a in areas.values)
                                a.area: mouthMapStyle(
                                  a.state,
                                  selected: a.area == selected,
                                ),
                            }),
                          ),
                        ),
                      ),
                      for (final (text, x, y) in const [
                        ('Upper', 150.0, 100.0),
                        ('Lower', 150.0, 226.0),
                      ])
                        Positioned(
                          left: (x - 40) * scale,
                          top: (y - 8) * scale,
                          width: 80 * scale,
                          child: Text(
                            text.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            textScaler: TextScaler.noScaling,
                            style: capsLabel(),
                          ),
                        ),
                      // Mirror style, like the scan guide: their left on the left.
                      for (final (text, x) in const [('L', 8.0), ('R', 292.0)])
                        Positioned(
                          left: (x - 10) * scale,
                          top: (163 - 8) * scale,
                          width: 20 * scale,
                          child: ExcludeSemantics(
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              textScaler: TextScaler.noScaling,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      for (final a in areas.values)
                        _AreaTarget(
                          report: a,
                          bounds: MouthMapPainter.areaBounds[a.area]!,
                          scale: scale,
                          selected: a.area == selected,
                          onTap: () => setState(() => _selected = a.area),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ReportLegend(shown, alignment: WrapAlignment.center),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: ReportColors.rule),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: ScanMotion.of(context, ScanMotion.medium),
            curve: ScanMotion.curve,
            alignment: Alignment.topCenter,
            child: selected == null
                ? Text(
                    'Tap an area to see what was read there.',
                    style: reportBody,
                  )
                : _AreaDetail(
                    key: ValueKey(selected),
                    report: areas[selected]!,
                    onSeeSpot: widget.onSeeSpot,
                  ),
          ),
        ],
      ),
    );
  }
}

/// A tap target over one area, which is also how a screen reader goes through
/// the map.
class _AreaTarget extends StatelessWidget {
  const _AreaTarget({
    required this.report,
    required this.bounds,
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  final AreaReport report;
  final Rect bounds;
  final double scale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final box = bounds.inflate(4);
    return Positioned(
      left: box.left * scale,
      top: box.top * scale,
      width: box.width * scale,
      height: box.height * scale,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${report.area.label}: ${areaStateLabel(report.state)}',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// What's behind the selected area's colour.
class _AreaDetail extends StatelessWidget {
  const _AreaDetail({super.key, required this.report, required this.onSeeSpot});

  final AreaReport report;
  final ValueChanged<ReportSpot> onSeeSpot;

  String get _sentence {
    final count = report.photoIds.length;
    final photos = '$count ${count == 1 ? 'photo' : 'photos'}';
    final spots = report.spots;
    return switch (report.state) {
      AreaState.notTaken => 'No photo of this area in this scan.',
      AreaState.retake => 'The photo of this area needs a retake.',
      AreaState.notRead =>
        'Photos of this area are saved, but this check can\'t read that view yet.',
      AreaState.clear => 'Read in $photos. Nothing was flagged.',
      _ => 'Seen in your ${_photoNames(spots)} '
          '${spots.map((s) => s.photoId).toSet().length == 1 ? 'photo' : 'photos'}.',
    };
  }

  static String _photoNames(List<ReportSpot> spots) {
    final names = {
      for (final s in spots) findScanRegion(s.photoId)?.short ?? '',
    }.where((n) => n.isNotEmpty);
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final spots = report.spots;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: ReportSwatch(report.state, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.area.label, style: reportCardTitle),
                const SizedBox(height: 1),
                Text(
                  [
                    if (spots.isNotEmpty)
                      '${spots.length} ${spots.length == 1 ? 'sign' : 'signs'}',
                    _sentence,
                  ].join(' · '),
                  style: reportBody,
                ),
              ],
            ),
          ),
          if (spots.isNotEmpty)
            TextButton(
              onPressed: () => onSeeSpot(spots.first),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('See it'),
            ),
        ],
      ),
    );
  }
}
