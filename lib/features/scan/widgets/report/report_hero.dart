import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/care_plan.dart';
import '../../data/patient_context.dart';
import '../../data/scan_outcomes.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_report.dart';
import '../../data/tooth_guidance.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import 'mouth_3d.dart';
import 'report_motion.dart';
import 'report_style.dart';

/// The top of the page: the 3D mouth floating above a glass card that holds the
/// result, what to do about it, and the numbers behind it.
class ReportHero extends StatefulWidget {
  const ReportHero({
    super.key,
    required this.report,
    required this.plan,
    required this.context,
    required this.trend,
    required this.status,
    required this.date,
    required this.leading,
    required this.focus,
    required this.onSeeSpot,
    this.time,
  });

  final ScreeningReport report;
  final CarePlan plan;
  final PatientContext context;
  final ScanTrend trend;

  /// How the scan went, e.g. "Scan complete".
  final String status;
  final String date;

  /// When in the day it was taken, if known.
  final String? time;

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

  /// Shows the area's marked teeth one after another, tap by tap.
  void _onAreaTap(MouthArea area) {
    final spots = widget.report.areas[area]!.spots;
    if (spots.isEmpty) {
      setState(() => _tapped = area);
      return;
    }
    setState(() => _tapped = null);
    final shown = widget.focus.value;
    final i = shown == null
        ? -1
        : spots.indexWhere((s) => identical(s.finding, shown.finding));
    widget.onSeeSpot(spots[(i + 1) % spots.length]);
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
        _ResultCard(
          report: report,
          plan: widget.plan,
          context_: widget.context,
          trend: widget.trend,
          status: widget.status,
          date: widget.date,
          time: widget.time,
          leading: widget.leading,
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

/// The result at a glance, in three layers: what was found, what to do about
/// it, and the figures behind it. What the user told us sits apart at the bottom,
/// so it never reads as something the check saw.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.report,
    required this.plan,
    required this.context_,
    required this.trend,
    required this.status,
    required this.date,
    required this.leading,
    this.time,
  });

  final ScreeningReport report;
  final CarePlan plan;
  final PatientContext context_;
  final ScanTrend trend;
  final String status;
  final String date;
  final String? time;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final read = report.photosRead > 0;
    final symptoms = context_.symptoms;
    final records = context_.records.length;
    final showsCare = read || plan.steps.isNotEmpty;
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      time == null ? date : '$date, $time',
                      style: reportNote,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(report.findingLine, style: reportHeadline),
          ),
          const SizedBox(height: 5),
          Text(_meaning, style: reportBody),
          if (showsCare) ...[
            const SizedBox(height: 14),
            _NextStep(plan: plan),
          ],
          if (read) ...[
            const SizedBox(height: 6),
            _Figures(report: report, trend: trend),
            const SizedBox(height: 8),
            const _ScopeLine(),
          ],
          if (symptoms != null || records > 0) ...[
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: ReportColors.rule),
            const SizedBox(height: 12),
            if (symptoms != null)
              _ContextRow(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'You told us',
                value: _symptomsLine(symptoms),
              ),
            if (symptoms != null && records > 0) const SizedBox(height: 8),
            if (records > 0)
              _ContextRow(
                icon: Icons.folder_outlined,
                label: 'Your records',
                value: _recordsLine,
              ),
          ],
        ],
      ),
    );
  }

  /// What the headline means. Only ever about the photos.
  String get _meaning {
    if (report.photosRead == 0) return report.analysis.summary;
    if (report.signCount > 0) {
      final counted = [
        for (final s in report.spots)
          if (s.strength != SignStrength.faint) s,
      ];
      final lead = counted.length == 1
          ? '${toothPlace(counted.single, capital: true)} may have tooth decay.'
          : 'Areas to have checked: '
              '${describeAreas({for (final s in counted) ...s.areas}).toLowerCase()}.';
      return '$lead This is a screening, not a diagnosis. Only a dentist can '
          'say what these marks are.';
    }
    if (report.faintCount > 0) {
      return 'Too unsure to act on. We\'ll compare them on your next scan.';
    }
    final n = report.photosRead;
    return 'Nothing marked in the $n ${n == 1 ? 'photo' : 'photos'} we could '
        'read. This check can miss early decay, so it can\'t promise there\'s '
        'none.';
  }

  static String _symptomsLine(ReportedSymptoms s) {
    final what = s.what;
    final line = [
      '${what[0].toUpperCase()}${what.substring(1)}',
      if (s.where case final where?) where,
      if (s.worsening) 'getting worse',
      if (s.old && s.answeredOn != null) 'on your profile',
    ];
    return line.join(', ');
  }

  /// How many entries, and how many touch something in this result.
  String get _recordsLine {
    final total = context_.records.length;
    final near = context_.recordsIn({
      for (final s in report.spots) ...s.areas,
      ...?context_.symptoms?.areas,
    }).length;
    final entries = '$total ${total == 1 ? 'entry' : 'entries'}';
    return near == 0 ? entries : '$entries, $near in the same general area';
  }
}

/// When to see a dentist: the step in words, why, and where it sits on a scale.
class _NextStep extends StatelessWidget {
  const _NextStep({required this.plan});

  final CarePlan plan;

  /// The stops on the scale. An emergency is off it, and is said instead.
  static const _stops = [
    CareLevel.routine,
    CareLevel.nextVisit,
    CareLevel.soon,
    CareLevel.prompt,
  ];

  IconData get _icon => switch (plan.level) {
        CareLevel.emergency => Icons.emergency_outlined,
        CareLevel.prompt => Icons.priority_high_rounded,
        CareLevel.soon => Icons.event_outlined,
        CareLevel.nextVisit => Icons.event_note_outlined,
        CareLevel.routine => Icons.event_available_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final level = plan.level;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.g2.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScanIconDisc(_icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'When to see a dentist',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ScanColors.clearInk,
                      ),
                    ),
                    Text(
                      plan.title,
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(plan.because, style: reportNote),
                  ],
                ),
              ),
            ],
          ),
          if (level != CareLevel.emergency) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'On a scale from regular check-ups to promptly, this is '
                  '${level.short}.',
              excludeSemantics: true,
              child: InViewAnimation(
                builder: (context, t) => _CareScale(
                  stops: _stops,
                  index: _stops.indexOf(level),
                  t: t,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rail with a stop for each step, filled up to the result's own, and its name
/// under each so it reads without colour too.
class _CareScale extends StatelessWidget {
  const _CareScale({required this.stops, required this.index, required this.t});

  final List<CareLevel> stops;
  final int index;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 14,
          child: CustomPaint(
            painter: _CareScalePainter(count: stops.length, index: index, t: t),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (final (i, stop) in stops.indexed)
              Expanded(
                // One word each, shrunk rather than broken when text is large.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: switch (i) {
                    0 => Alignment.centerLeft,
                    _ when i == stops.length - 1 => Alignment.centerRight,
                    _ => Alignment.center,
                  },
                  child: Text(
                    stop.short,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight:
                          i == index ? FontWeight.w800 : FontWeight.w500,
                      color: i == index
                          ? ScanColors.clearInk
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CareScalePainter extends CustomPainter {
  const _CareScalePainter({
    required this.count,
    required this.index,
    required this.t,
  });

  final int count;
  final int index;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    // The labels sit at the ends and the centres of equal columns.
    final cell = size.width / count;
    double x(int i) => i == 0
        ? 7.0
        : i == count - 1
            ? size.width - 7
            : cell * (i + 0.5);
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x(0), y),
      Offset(x(count - 1), y),
      line..color = AppColors.g2.withValues(alpha: 0.18),
    );
    final end = x(0) + (x(index) - x(0)) * t;
    canvas.drawLine(
      Offset(x(0), y),
      Offset(end, y),
      line..color = AppColors.primary,
    );
    for (var i = 0; i < count; i++) {
      final reached = i <= index && x(i) <= end + 0.5;
      final here = i == index && reached;
      canvas.drawCircle(
        Offset(x(i), y),
        here ? 7 : 4,
        Paint()..color = reached ? AppColors.primary : AppColors.white,
      );
      if (!reached) {
        canvas.drawCircle(
          Offset(x(i), y),
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.g2.withValues(alpha: 0.32),
        );
      }
      if (here) {
        canvas.drawCircle(
            Offset(x(i), y), 2.6, Paint()..color = AppColors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_CareScalePainter old) =>
      old.t != t || old.index != index || old.count != count;
}

/// Four small figures, each with a picture of its own: where, how sure, how much
/// was read, and how it compares. Two across, or one when text is large.
class _Figures extends StatelessWidget {
  const _Figures({required this.report, required this.trend});

  final ScreeningReport report;
  final ScanTrend trend;

  @override
  Widget build(BuildContext context) {
    final range = report.confidenceRange;
    final strong = report.countOf(SignStrength.strong);
    final possible = report.countOf(SignStrength.possible);
    final faint = report.countOf(SignStrength.faint);
    final strengths = [
      if (strong > 0) '$strong strong',
      if (possible > 0) '$possible possible',
      if (faint > 0) '$faint faint',
    ].join(', ');
    final flagged = [
      for (final a in report.areas.values)
        if (a.state.flagged) a.area,
    ];
    final surfaces = report.surfaces;
    final surfacesRead = surfaces?.fold<int>(0, (sum, s) => sum + s.$2);
    final tiles = <Widget>[
      _Figure(
        label: 'Areas checked',
        value: '${report.areasRead}',
        unit: ' of ${MouthArea.values.length}',
        caption: flagged.isEmpty && report.areasUnread == 0
            ? 'Nothing marked'
            : [
                if (report.areasToCheck > 0) '${report.areasToCheck} to check',
                if (report.areasToWatch > 0) '${report.areasToWatch} to watch',
                if (report.areasClear > 0) '${report.areasClear} clear',
                if (report.areasUnread > 0) '${report.areasUnread} not read',
              ].join(', '),
        visual: _AreaCells(report: report),
      ),
      if (range != null)
        _Figure(
          label: 'Model confidence',
          value: range.$1 == range.$2
              ? '${range.$1}%'
              : '${range.$1}–${range.$2}%',
          caption: strengths,
          visual: _ConfidenceStrip(report: report),
        )
      else if (surfaces != null)
        _Figure(
          label: 'Surfaces read',
          value: '$surfacesRead',
          unit: ' of ${surfaces.length * MouthArea.values.length}',
          caption: 'Across every area',
          visual: _ReadBar(
            read: surfacesRead!,
            total: surfaces.length * MouthArea.values.length,
          ),
        ),
      _Figure(
        label: report.guided ? 'Views read' : 'Photos read',
        value: '${report.viewsRead}',
        unit: ' of ${report.viewsTotal}',
        caption: report.photosToRetake > 0
            ? '${report.photosToRetake} to retake'
            : '${report.photosRead} ${report.photosRead == 1 ? 'photo' : 'photos'} read',
        visual: _ViewTicks(report: report),
      ),
      _Figure(
        label: 'Compared with last scan',
        value: _comparison,
        caption: _comparisonCaption,
        visual: _TrendBars(trend: trend),
      ),
    ];
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth / scale >= 250;
      if (!wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tile in tiles) tile,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i += 2)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tiles[i]),
                  VerticalDivider(
                    width: 17,
                    thickness: 1,
                    indent: 12,
                    endIndent: 4,
                    color: ReportColors.rule,
                  ),
                  Expanded(
                    child: i + 1 < tiles.length
                        ? tiles[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  /// Only says what both scans could read.
  String get _comparison {
    if (!trend.hasHistory) return 'First scan';
    if (trend.mixedVersions) return 'Not comparable';
    if (trend.newAreas.isNotEmpty) {
      final n = trend.newAreas.length;
      return '$n new ${n == 1 ? 'area' : 'areas'}';
    }
    if (trend.clearedAreas.isNotEmpty) {
      final n = trend.clearedAreas.length;
      return '$n not flagged';
    }
    return 'No change';
  }

  String get _comparisonCaption {
    if (!trend.hasHistory) return 'Scan again to see changes';
    if (trend.mixedVersions) return 'The check has since been updated';
    if (trend.repeating.isNotEmpty) return 'One area keeps being marked';
    if (trend.newAreas.isNotEmpty) return describeAreas(trend.newAreas.toSet());
    if (trend.clearedAreas.isNotEmpty) {
      return 'Flagged last time, not now: '
          '${describeAreas(trend.clearedAreas.toSet()).toLowerCase()}';
    }
    return 'Same areas flagged';
  }
}

/// One figure: its label, a small picture, the number, and a line on what it is.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.caption,
    required this.visual,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
  final String caption;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value${unit ?? ''}. $caption.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: reportNote),
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(
                text: value,
                style: figureText(size: 19, weight: FontWeight.w800),
                children: [
                  if (unit != null)
                    TextSpan(
                      text: unit,
                      style: figureText(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(height: 24, width: double.infinity, child: visual),
            const SizedBox(height: 6),
            Text(caption, style: reportNote),
          ],
        ),
      ),
    );
  }
}

/// The six areas in two rows, as on a chart of the mouth, each in its state's
/// shade. Upper right is on the left, as a dentist sees it.
class _AreaCells extends StatelessWidget {
  const _AreaCells({required this.report});

  final ScreeningReport report;

  static const _rows = [
    [MouthArea.upperRight, MouthArea.upperFront, MouthArea.upperLeft],
    [MouthArea.lowerRight, MouthArea.lowerFront, MouthArea.lowerLeft],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (r, row) in _rows.indexed) ...[
          if (r > 0) const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                for (final (c, area) in row.indexed) ...[
                  if (c > 0) const SizedBox(width: 2),
                  Expanded(child: _cell(report.areas[area]!.state)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cell(AreaState state) => Container(
        decoration: BoxDecoration(
          color: ReportColors.of(state),
          borderRadius: BorderRadius.circular(3),
          border:
              state.read ? null : Border.all(color: ReportColors.hollowEdge),
        ),
      );
}

/// Every sign on one line from 0 to 100, a mark where the model put it.
class _ConfidenceStrip extends StatelessWidget {
  const _ConfidenceStrip({required this.report});

  final ScreeningReport report;

  @override
  Widget build(BuildContext context) {
    return InViewAnimation(
      builder: (context, t) => CustomPaint(
        painter: _StripPainter(
          marks: [
            for (final s in report.spots)
              if (s.percent case final p?)
                (p / 100, ReportColors.ofSign(s.strength)),
          ],
          t: t,
        ),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  const _StripPainter({required this.marks, required this.t});

  final List<(double, Color)> marks;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.g2.withValues(alpha: 0.16),
    );
    for (final (value, color) in marks) {
      final x = value * size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y),
            width: 4,
            height: 18 * t,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) => old.t != t || old.marks != marks;
}

/// A bar of how much was read, for a result with nothing marked.
class _ReadBar extends StatelessWidget {
  const _ReadBar({required this.read, required this.total});

  final int read;
  final int total;

  @override
  Widget build(BuildContext context) {
    return InViewAnimation(
      builder: (context, t) => Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: AppColors.g2.withValues(alpha: 0.14)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: total == 0 ? 0 : t * read / total,
                  child: const ColoredBox(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tick for each guided view: solid when read, pale when saved but not read,
/// hollow when there's no usable photo.
class _ViewTicks extends StatelessWidget {
  const _ViewTicks({required this.report});

  final ScreeningReport report;

  @override
  Widget build(BuildContext context) {
    final ids =
        report.guided ? [for (final r in scanRegions) r.id] : report.photoIds;
    return Row(
      children: [
        for (final (i, id) in ids.indexed) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(child: _tick(id)),
        ],
      ],
    );
  }

  Widget _tick(String id) {
    final outcomes = [report.outcomes[id], report.outcomes[secondPhotoId(id)]];
    final read = outcomes.any((o) => o?.checked ?? false);
    final saved = outcomes.contains(ViewOutcome.notChecked);
    return Container(
      decoration: BoxDecoration(
        color: read
            ? AppColors.primary
            : saved
                ? ReportColors.clear
                : ReportColors.hollow,
        borderRadius: BorderRadius.circular(2),
        border:
            read || saved ? null : Border.all(color: ReportColors.hollowEdge),
      ),
    );
  }
}

/// Signs at each scan, oldest to this one, which is the solid bar.
class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.trend});

  final ScanTrend trend;

  @override
  Widget build(BuildContext context) {
    final points = trend.points;
    final most = points.fold<int>(
      1,
      (m, p) => math.max(m, p.report.spots.length),
    );
    return InViewAnimation(
      builder: (context, t) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, p) in points.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(
              width: 10,
              height: 3 + 21 * t * p.report.spots.length / most,
              decoration: BoxDecoration(
                color: i == points.length - 1
                    ? AppColors.primary
                    : ReportColors.clear,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What a result can't speak to, kept in view next to the figures.
class _ScopeLine extends StatelessWidget {
  const _ScopeLine();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Not read by this check: plaque, tartar, gums and inner sides.',
      style: reportNote,
    );
  }
}

/// Something that came from the user, not from the photos.
class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScanIconDisc(icon, size: 28, iconSize: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: reportNote),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
