import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../history/screens/screening_detail_screen.dart';
import '../../scan/data/scan_regions.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';

enum ActivityRange {
  days30('30D', 'last 30 days', 30),
  months3('3M', 'last 3 months', 91),
  months6('6M', 'last 6 months', 182);

  const ActivityRange(this.label, this.spoken, this.days);
  final String label;
  final String spoken;
  final int days;
}

/// Home's history graph: one mark per saved AI screening, placed at its
/// date, its height the number of regions captured.
///
/// Region coverage is the only number every screening stores the same
/// way. It says how complete a screening was, not how healthy teeth are,
/// and the card says so. No score is derived, AI confidence is never
/// plotted, and user-entered records stay out of it.
class ScreeningActivityCard extends ConsumerStatefulWidget {
  const ScreeningActivityCard({super.key});

  @override
  ConsumerState<ScreeningActivityCard> createState() =>
      _ScreeningActivityCardState();
}

class _ScreeningActivityCardState extends ConsumerState<ScreeningActivityCard> {
  ActivityRange _range = ActivityRange.months3;

  /// Day of the tapped mark; null when nothing is selected.
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(screeningSessionsProvider);
    final now = DateTime.now();
    final end = DentraDates.dateOnly(now).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: _range.days));
    final all = async.valueOrNull ?? const <ScreeningSession>[];
    final inRange = [
      for (final s in all)
        if (!s.completedAt.isBefore(start) && s.completedAt.isBefore(end)) s,
    ]..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final selected = _selectedDay == null
        ? const <ScreeningSession>[]
        : inRange
            .where((s) => DentraDates.sameDay(s.completedAt, _selectedDay!))
            .toList();

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Screening activity',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      async.hasValue
                          ? '${inRange.length} ${inRange.length == 1 ? 'screening' : 'screenings'} · ${_range.spoken}'
                          : 'Regions captured per AI screening',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              _RangeToggle(
                value: _range,
                onChanged: (r) => setState(() {
                  _range = r;
                  _selectedDay = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: dentraMotion(context, 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _content(async, all, inRange, start, end, selected),
          ),
        ],
      ),
    );
  }

  Widget _content(
    AsyncValue<List<ScreeningSession>> async,
    List<ScreeningSession> all,
    List<ScreeningSession> inRange,
    DateTime start,
    DateTime end,
    List<ScreeningSession> selected,
  ) {
    if (async.hasError && !async.hasValue) {
      return _Message(
        text: "Your screening history couldn't load.",
        action: TextButton(
          onPressed: () => ref.invalidate(screeningSessionsProvider),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(44, 44),
          ),
          child: Text('Try again',
              style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    }
    if (!async.hasValue) return const _ChartSkeleton();
    if (all.isEmpty) {
      return _EmptyChart(
        key: ValueKey('empty-$_range'),
        start: start,
        end: end,
        placeholder: true,
        text: 'No screenings yet. Your activity will appear here after your '
            'first scan.',
      );
    }
    if (inRange.isEmpty) {
      final latest = all.first.completedAt;
      return _EmptyChart(
        key: ValueKey('none-$_range'),
        start: start,
        end: end,
        text: 'No screenings in the ${_range.spoken}. Your latest was on '
            '${DentraDates.medium(latest)}.',
      );
    }

    final maxRegions = inRange.map((s) => s.totalRegions).fold(1, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Chart(
          key: ValueKey(_range),
          sessions: inRange,
          start: start,
          end: end,
          maxRegions: maxRegions,
          selectedDay: _selectedDay,
          summary: _summary(inRange),
          onSelectDay: (d) => setState(() => _selectedDay = d != null &&
                  _selectedDay != null &&
                  DentraDates.sameDay(d, _selectedDay!)
              ? null
              : d),
        ),
        const SizedBox(height: 6),
        Text(
          'Height shows regions captured, out of $maxRegions. It reflects how '
          'complete each screening was, not your dental health.',
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: AppColors.secondaryText,
            height: 1.4,
          ),
        ),
        AnimatedSwitcher(
          duration: dentraMotion(context, 180),
          child: selected.isEmpty
              ? const SizedBox(width: double.infinity)
              : _Details(key: ValueKey(_selectedDay), sessions: selected),
        ),
      ],
    );
  }

  String _summary(List<ScreeningSession> sessions) {
    final shown = sessions.reversed.take(8).map((s) =>
        '${DentraDates.medium(s.completedAt)}, ${s.capturedRegions.length} of '
        '${s.totalRegions} regions');
    final more = sessions.length > 8 ? ', and ${sessions.length - 8} more' : '';
    return 'Screening activity, ${_range.spoken}: ${sessions.length} '
        '${sessions.length == 1 ? 'screening' : 'screenings'}. '
        '${shown.join('; ')}$more.';
  }
}

// ── Chart ───────────────────────────────────────────────────────────────────

class _Chart extends StatelessWidget {
  const _Chart({
    super.key,
    required this.sessions,
    required this.start,
    required this.end,
    required this.maxRegions,
    required this.selectedDay,
    required this.summary,
    required this.onSelectDay,
  });

  final List<ScreeningSession> sessions;
  final DateTime start;
  final DateTime end;
  final int maxRegions;
  final DateTime? selectedDay;
  final String summary;
  final ValueChanged<DateTime?> onSelectDay;

  static const double _height = 132;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: summary,
      hint: 'Tap a mark for its details.',
      child: LayoutBuilder(builder: (context, c) {
        final geometry =
            _Geometry(Size(c.maxWidth, _height), start, end, maxRegions);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) =>
              onSelectDay(geometry.dayAt(d.localPosition, sessions)),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              size: Size(c.maxWidth, _height),
              painter: _ActivityPainter(
                geometry: geometry,
                sessions: sessions,
                selectedDay: selectedDay,
                progress: t,
                labelStyle: GoogleFonts.outfit(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// The chart's frame (axes and dates for the chosen range) with a short
/// message under it, for when there is nothing to plot. With [placeholder]
/// it also shows faint example marks so new users see what the graph will
/// look like. They are decoration only: no dots, no values, hidden from
/// screen readers, and never shaped like real data.
class _EmptyChart extends StatelessWidget {
  const _EmptyChart({
    super.key,
    required this.start,
    required this.end,
    required this.text,
    this.placeholder = false,
  });

  final DateTime start;
  final DateTime end;
  final String text;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(builder: (context, c) {
      final geometry = _Geometry(
          Size(c.maxWidth, _Chart._height), start, end, scanRegions.length);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                size: Size(c.maxWidth, _Chart._height),
                painter: _ActivityPainter(
                  geometry: geometry,
                  sessions: const [],
                  selectedDay: null,
                  progress: t,
                  placeholder: placeholder,
                  labelStyle: GoogleFonts.outfit(
                    fontSize: 10,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: AppColors.secondaryText,
                height: 1.45,
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Maps dates and region counts to the chart's pixels.
class _Geometry {
  _Geometry(this.size, this.start, this.end, this.maxRegions);

  final Size size;
  final DateTime start;
  final DateTime end;
  final int maxRegions;

  static const double left = 18, right = 8, top = 8, bottom = 22;

  Rect get plot =>
      Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

  double xOf(DateTime t) {
    final span = end.difference(start).inMinutes;
    final f = span == 0 ? 0.5 : t.difference(start).inMinutes / span;
    return plot.left + f.clamp(0.0, 1.0) * plot.width;
  }

  double yOf(num regions) => plot.bottom - (regions / maxRegions) * plot.height;

  /// The day of the mark nearest a tap, within a finger's reach.
  DateTime? dayAt(Offset p, List<ScreeningSession> sessions) {
    ScreeningSession? best;
    var bestDist = 24.0;
    for (final s in sessions) {
      final d = (xOf(s.completedAt) - p.dx).abs();
      if (d < bestDist) {
        best = s;
        bestDist = d;
      }
    }
    return best == null ? null : DentraDates.dateOnly(best.completedAt);
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter({
    required this.geometry,
    required this.sessions,
    required this.selectedDay,
    required this.progress,
    required this.labelStyle,
    this.placeholder = false,
  });

  final _Geometry geometry;
  final List<ScreeningSession> sessions;
  final DateTime? selectedDay;
  final double progress;
  final TextStyle labelStyle;

  /// Faint example stems for the empty state. Not data.
  final bool placeholder;

  /// Positions across the range and heights (0–1) of the example stems.
  static const _examples = [
    (0.1, 0.45),
    (0.24, 0.8),
    (0.38, 0.6),
    (0.52, 1.0),
    (0.66, 0.7),
    (0.8, 0.9),
    (0.93, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final plot = g.plot;

    // Recessive hairlines: baseline and the all-regions line.
    final grid = Paint()
      ..color = AppGlass.divider
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(plot.left, plot.bottom), Offset(plot.right, plot.bottom), grid);
    canvas.drawLine(Offset(plot.left, g.yOf(g.maxRegions)),
        Offset(plot.right, g.yOf(g.maxRegions)), grid);

    _text(canvas, '${g.maxRegions}', Offset(0, g.yOf(g.maxRegions) - 6));
    _text(canvas, '0', Offset(0, plot.bottom - 6));

    // Date labels: start, middle and today.
    final mid = g.start.add(g.end.difference(g.start) ~/ 2);
    String short(DateTime d) => '${DentraDates.monthShort(d.month)} ${d.day}';
    _text(canvas, short(g.start), Offset(plot.left, plot.bottom + 6));
    _text(canvas, short(mid), Offset(g.xOf(mid), plot.bottom + 6),
        center: true);
    _text(canvas, 'Today', Offset(plot.right, plot.bottom + 6),
        alignRight: true);

    final stem = Paint()
      ..color = AppColors.g2.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = AppColors.g2;
    final ring = Paint()..color = AppColors.white;
    final guide = Paint()
      ..color = AppColors.g2.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    if (placeholder) {
      final ghost = Paint()
        ..color = AppColors.g2.withValues(alpha: 0.16)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      for (final (fx, fh) in _examples) {
        final x = plot.left + fx * plot.width;
        // Rounded caps sit inside the plot, clear of the gridlines.
        final y = plot.bottom - 3 - fh * (plot.height - 6) * progress;
        canvas.drawLine(Offset(x, plot.bottom - 3), Offset(x, y), ghost);
      }
    }

    for (final s in sessions) {
      final x = g.xOf(s.completedAt);
      final regions = s.capturedRegions.length * progress;
      final y = g.yOf(regions);
      final isSelected = selectedDay != null &&
          DentraDates.sameDay(s.completedAt, selectedDay!);
      if (isSelected) {
        canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), guide);
      }
      canvas.drawLine(Offset(x, plot.bottom), Offset(x, y), stem);
      final r = isSelected ? 6.0 : 4.5;
      canvas.drawCircle(Offset(x, y), r + 2, ring);
      canvas.drawCircle(Offset(x, y), r, dot);
    }
  }

  void _text(Canvas canvas, String text, Offset at,
      {bool center = false, bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center
        ? at.dx - tp.width / 2
        : alignRight
            ? at.dx - tp.width
            : at.dx;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_ActivityPainter old) =>
      old.progress != progress ||
      old.placeholder != placeholder ||
      old.selectedDay != selectedDay ||
      old.sessions != sessions ||
      old.geometry.size != geometry.size;
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// The tapped day's screenings, with a way into each one's details.
class _Details extends StatelessWidget {
  const _Details({super.key, required this.sessions});

  final List<ScreeningSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Divider(height: 1, color: AppGlass.divider),
          for (final s in sessions)
            InkWell(
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .push(ScreeningDetailScreen.route(s.id)),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DentraDates.medium(s.completedAt)} · '
                            '${DentraDates.time(s.completedAt)}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            '${s.capturedRegions.length} of ${s.totalRegions} '
                            'regions captured · '
                            '${s.analysis == null ? 'No AI analysis saved' : 'AI analysis saved'}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Open',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Quiet text toggle: the active range is navy with a short teal
/// underline; the others stay muted. No container, no shadow.
class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.value, required this.onChanged});

  final ActivityRange value;
  final ValueChanged<ActivityRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final motion = dentraMotion(context, 180);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in ActivityRange.values)
          Semantics(
            button: true,
            selected: r == value,
            inMutuallyExclusiveGroup: true,
            label: 'Show the ${r.spoken}',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(r),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: motion,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight:
                              r == value ? FontWeight.w700 : FontWeight.w500,
                          color: r == value
                              ? AppColors.navy
                              : AppColors.secondaryText,
                        ),
                        child: Text(r.label),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: motion,
                        curve: Curves.easeOut,
                        width: r == value ? 14 : 0,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.g2,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        decoration: BoxDecoration(
          color: AppColors.lightLavender.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  height: 1.45,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: _Chart._height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final h in const [0.4, 0.7, 0.55, 0.9, 0.6])
              Container(
                width: 4,
                height: (_Chart._height - 30) * h,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: AppColors.g2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
