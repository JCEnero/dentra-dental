import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/dentra_dates.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_report.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import 'report_style.dart';

/// How this scan compares with the ones before: signs per scan above a row per
/// mouth area, so a sign that keeps showing up in one place stands out. Light
/// and angle change between scans, so the page says what a change can't prove.
class TrendSection extends StatefulWidget {
  const TrendSection({super.key, required this.trend});

  final ScanTrend trend;

  @override
  State<TrendSection> createState() => _TrendSectionState();
}

class _TrendSectionState extends State<TrendSection> {
  static const _labelWidth = 66.0;
  static const _barsHeight = 72.0;

  /// Wide enough to read as a column even with only two scans.
  static const _maxColumnWidth = 44.0;

  /// The tapped scan; the latest until then.
  int? _selected;

  // In the same order as the map's columns, top to bottom.
  static const _rows = [
    (MouthArea.upperLeft, 'Upper left'),
    (MouthArea.upperFront, 'Upper front'),
    (MouthArea.upperRight, 'Upper right'),
    (MouthArea.lowerLeft, 'Lower left'),
    (MouthArea.lowerFront, 'Lower front'),
    (MouthArea.lowerRight, 'Lower right'),
  ];

  String _names(Iterable<MouthArea> areas) =>
      areas.map((a) => a.label.toLowerCase()).join(', ');

  /// What changed since the scan before, in words.
  List<String> _changes() {
    final t = widget.trend;
    final repeating = t.repeating;
    return [
      if (repeating.isNotEmpty)
        'Showing up scan after scan: ${_names(repeating.keys)}. That\'s worth '
            'showing a dentist, even if each one looks faint.',
      if (t.newAreas.isNotEmpty) 'New since last scan: ${_names(t.newAreas)}.',
      if (t.clearedAreas.isNotEmpty)
        'No longer flagged: ${_names(t.clearedAreas)}.',
      if (t.newAreas.isEmpty && t.clearedAreas.isEmpty && repeating.isEmpty)
        'No change in which areas are flagged since your last scan.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.trend.points;
    if (!widget.trend.hasHistory) {
      return const _Baseline();
    }
    final selected = _selected ?? points.length - 1;
    final top = math.max(
      1,
      points.map((p) => p.report.spots.length).reduce(math.max),
    );
    final shown = points[selected];
    final states = {
      for (final p in points)
        for (final a in p.report.areas.values) a.state,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, line) in _changes().indexed) ...[
          if (i > 0) const SizedBox(height: 4),
          Text(
            line,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.navy,
            ),
          ),
        ],
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final column = math.min(
            (c.maxWidth - _labelWidth) / points.length,
            _maxColumnWidth,
          );
          final latestEdge = _labelWidth + column * points.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bars, each scan's column lining up with its cells below.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: _labelWidth,
                    height: _barsHeight,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        '$top ${top == 1 ? 'sign' : 'signs'}',
                        style: reportNote,
                      ),
                    ),
                  ),
                  for (final (i, p) in points.indexed)
                    SizedBox(
                      width: column,
                      child: _ScanBar(
                        point: p,
                        top: top,
                        height: _barsHeight,
                        selected: i == selected,
                        onTap: () => setState(() => _selected = i),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: _labelWidth,
                  right: c.maxWidth - latestEdge,
                ),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: ReportColors.rule,
                ),
              ),
              const SizedBox(height: 6),
              for (final (area, label) in _rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _labelWidth,
                        child: ExcludeSemantics(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      for (final p in points)
                        SizedBox(
                          width: column,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1.5),
                            child: _TimelineCell(
                              area: area,
                              state: p.report.areas[area]!.state,
                              at: p.at,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Padding(
                padding: EdgeInsets.only(
                  left: _labelWidth,
                  right: c.maxWidth - latestEdge,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(_short(points.first.at), style: reportNote),
                    ),
                    Flexible(
                      child: Text(_short(points.last.at), style: reportNote),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        ReportLegend(states),
        const SizedBox(height: 10),
        Divider(height: 1, thickness: 1, color: ReportColors.rule),
        const SizedBox(height: 8),
        Text(
          '${DentraDates.medium(shown.at)}: ${_describe(shown.report)}',
          style: figureText(
            size: 12.5,
            weight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Light and angle change between scans, so one small change may not '
          'mean much. What keeps showing up matters more.',
          style: reportNote,
        ),
      ],
    );
  }

  static String _short(DateTime d) =>
      '${DentraDates.monthShort(d.month)} ${d.day}';

  static String _describe(ScreeningReport r) {
    final signs = r.signCount, faint = r.faintCount;
    return [
      '$signs ${signs == 1 ? 'sign' : 'signs'}',
      if (faint > 0) '$faint faint',
      '${r.photosRead} photos read',
    ].join(' · ');
  }
}

/// One scan's signs, stacked by strength. The chosen scan stands out; the
/// others are context.
class _ScanBar extends StatelessWidget {
  const _ScanBar({
    required this.point,
    required this.top,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  final TrendPoint point;
  final int top;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  static const _width = 20.0;
  static const _gap = 2.0;
  static const _minSegment = 3.0;

  /// Faint at the top, strong on the baseline. Small counts keep a visible
  /// height, taken from the tallest so the stack still fits.
  List<(SignStrength, double)> _segments() {
    final counts = [
      for (final s in SignStrength.values)
        if (point.report.countOf(s) > 0) (s, point.report.countOf(s)),
    ];
    if (counts.isEmpty) return const [];
    final room = height - _gap * (counts.length - 1);
    final heights = [
      for (final (s, n) in counts) (s, math.max(_minSegment, room * n / top)),
    ];
    final used = heights.fold<double>(0, (sum, h) => sum + h.$2);
    if (used <= room) return heights;
    // Only the minimums can push it over, and only by a few pixels.
    final tallest =
        heights.indexed.reduce((a, b) => a.$2.$2 >= b.$2.$2 ? a : b).$1;
    heights[tallest] =
        (heights[tallest].$1, heights[tallest].$2 - (used - room));
    return heights;
  }

  @override
  Widget build(BuildContext context) {
    final r = point.report;
    final segments = _segments();
    return Semantics(
      button: true,
      selected: selected,
      label: '${DentraDates.medium(point.at)}: '
          '${r.signCount} ${r.signCount == 1 ? 'sign' : 'signs'}, '
          '${r.faintCount} faint',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: _width,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final (i, (strength, h)) in segments.indexed) ...[
                    if (i > 0) const SizedBox(height: _gap),
                    _Segment(
                      height: h,
                      color: ReportColors.ofSign(strength),
                      dim: !selected,
                      roundTop: i == 0,
                    ),
                  ],
                  // A scan with nothing still gets a mark on the baseline.
                  if (segments.isEmpty)
                    Container(
                      height: 2,
                      color: selected
                          ? AppColors.primary
                          : AppColors.navy.withValues(alpha: 0.15),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.height,
    required this.color,
    required this.dim,
    required this.roundTop,
  });

  final double height;
  final Color color;
  final bool dim;
  final bool roundTop;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ScanMotion.of(context, ScanMotion.fast),
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dim ? 0.5 : 1),
        borderRadius: roundTop
            ? const BorderRadius.vertical(top: Radius.circular(4))
            : null,
      ),
    );
  }
}

class _TimelineCell extends StatelessWidget {
  const _TimelineCell({
    required this.area,
    required this.state,
    required this.at,
  });

  final MouthArea area;
  final AreaState state;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${area.label}, ${DentraDates.medium(at)}: '
          '${areaStateLabel(state)}',
      excludeSemantics: true,
      child: Container(
        height: 13,
        decoration: BoxDecoration(
          color: ReportColors.of(state),
          borderRadius: BorderRadius.circular(3.5),
          border:
              state.read ? null : Border.all(color: ReportColors.hollowEdge),
        ),
      ),
    );
  }
}

/// The first scan: nothing to compare with yet, and that's the message.
class _Baseline extends StatelessWidget {
  const _Baseline();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Scan again in a few weeks and this will show what changed, area by area.',
      style: reportBody,
    );
  }
}
