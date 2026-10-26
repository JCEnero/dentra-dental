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
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';

enum ActivityRange {
  days30('30D', 'last 30 days', 10, 3, '3 days'),
  months3('3M', 'last 3 months', 13, 7, 'week'),
  months6('6M', 'last 6 months', 13, 14, '2 weeks');

  const ActivityRange(
      this.label, this.spoken, this.bins, this.binDays, this.binSpoken);
  final String label;
  final String spoken;

  /// Number of bars, each covering [binDays] days.
  final int bins;
  final int binDays;
  final String binSpoken;

  int get days => bins * binDays;
}

/// Home's history graph: how often the user ran an AI screening. Each bar
/// counts the saved screenings in one slice of the chosen range.
///
/// It shows frequency only, not how healthy teeth are, and the card says
/// so. No score is derived, AI confidence is never plotted, and
/// user-entered records stay out of it.
class ScreeningActivityCard extends ConsumerStatefulWidget {
  const ScreeningActivityCard({super.key});

  @override
  ConsumerState<ScreeningActivityCard> createState() =>
      _ScreeningActivityCardState();
}

class _ScreeningActivityCardState extends ConsumerState<ScreeningActivityCard> {
  ActivityRange _range = ActivityRange.months3;

  /// Index of the tapped bar; null when nothing is selected.
  int? _selectedBin;

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
                          : 'How often you screen',
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
                  _selectedBin = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: dentraMotion(context, 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _content(async, all, inRange, start, end),
          ),
        ],
      ),
    );
  }

  int _binOf(DateTime t, DateTime start) =>
      (t.difference(start).inMinutes ~/ (_range.binDays * 24 * 60))
          .clamp(0, _range.bins - 1);

  DateTime _binStart(int i, DateTime start) =>
      start.add(Duration(days: i * _range.binDays));

  Widget _content(
    AsyncValue<List<ScreeningSession>> async,
    List<ScreeningSession> all,
    List<ScreeningSession> inRange,
    DateTime start,
    DateTime end,
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
        bins: _range.bins,
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
        bins: _range.bins,
        text: 'No screenings in the ${_range.spoken}. Your latest was on '
            '${DentraDates.medium(latest)}.',
      );
    }

    final counts = List.filled(_range.bins, 0);
    for (final s in inRange) {
      counts[_binOf(s.completedAt, start)]++;
    }
    final maxCount = counts.fold(1, math.max);
    final selected = _selectedBin == null
        ? const <ScreeningSession>[]
        : inRange
            .where((s) => _binOf(s.completedAt, start) == _selectedBin)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Chart(
          key: ValueKey(_range),
          counts: counts,
          start: start,
          end: end,
          maxCount: maxCount,
          selectedBin: _selectedBin,
          summary: _summary(counts, start),
          onSelectBin: (i) =>
              setState(() => _selectedBin = i == _selectedBin ? null : i),
        ),
        const SizedBox(height: 6),
        Text(
          'Each bar counts your screenings in a ${_range.binSpoken}. It shows '
          'how often you screened, not your dental health.',
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
              : _Details(
                  key: ValueKey(_selectedBin),
                  title: _binLabel(_selectedBin!, start),
                  sessions: selected,
                ),
        ),
      ],
    );
  }

  /// "Sep 11 to Sep 17", with the last bar ending today.
  String _binLabel(int i, DateTime start) {
    String short(DateTime d) => '${DentraDates.monthShort(d.month)} ${d.day}';
    final from = _binStart(i, start);
    final to = _binStart(i + 1, start).subtract(const Duration(days: 1));
    return '${short(from)} to ${short(to)}';
  }

  String _summary(List<int> counts, DateTime start) {
    final total = counts.fold(0, (a, b) => a + b);
    final shown = [
      for (var i = counts.length - 1; i >= 0; i--)
        if (counts[i] > 0)
          '${_binLabel(i, start)}, ${counts[i]} '
              '${counts[i] == 1 ? 'screening' : 'screenings'}',
    ];
    return 'Screening activity, ${_range.spoken}: $total '
        '${total == 1 ? 'screening' : 'screenings'}. ${shown.join('; ')}.';
  }
}

// ── Chart ───────────────────────────────────────────────────────────────────

class _Chart extends StatelessWidget {
  const _Chart({
    super.key,
    required this.counts,
    required this.start,
    required this.end,
    required this.maxCount,
    required this.selectedBin,
    required this.summary,
    required this.onSelectBin,
  });

  final List<int> counts;
  final DateTime start;
  final DateTime end;
  final int maxCount;
  final int? selectedBin;
  final String summary;
  final ValueChanged<int?> onSelectBin;

  static const double _height = 132;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: summary,
      hint: 'Tap a bar for its screenings.',
      child: LayoutBuilder(builder: (context, c) {
        final geometry = _Geometry(
            Size(c.maxWidth, _height), start, end, counts.length, maxCount);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final i = geometry.binAt(d.localPosition);
            onSelectBin(i != null && counts[i] > 0 ? i : null);
          },
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
                counts: counts,
                selectedBin: selectedBin,
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

/// The chart's frame (baseline and dates for the chosen range) with a short
/// message under it, for when there is nothing to plot. With [placeholder]
/// it also shows faint example marks so new users see what the graph will
/// look like. They are decoration only: no values, hidden from screen
/// readers, and never shaped like real data.
class _EmptyChart extends StatelessWidget {
  const _EmptyChart({
    super.key,
    required this.start,
    required this.end,
    required this.bins,
    required this.text,
    this.placeholder = false,
  });

  final DateTime start;
  final DateTime end;
  final int bins;
  final String text;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(builder: (context, c) {
      final geometry =
          _Geometry(Size(c.maxWidth, _Chart._height), start, end, bins, 1);
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
                  counts: const [],
                  selectedBin: null,
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
                fontSize: 11,
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

/// Maps dates, bars and screening counts to the chart's pixels.
class _Geometry {
  _Geometry(this.size, this.start, this.end, this.bins, this.maxCount);

  final Size size;
  final DateTime start;
  final DateTime end;
  final int bins;
  final int maxCount;

  static const double left = 18, right = 8, top = 8, bottom = 22;

  Rect get plot =>
      Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

  double get binWidth => plot.width / bins;

  double centerOf(int bin) => plot.left + (bin + 0.5) * binWidth;

  double xOf(DateTime t) {
    final span = end.difference(start).inMinutes;
    final f = span == 0 ? 0.5 : t.difference(start).inMinutes / span;
    return plot.left + f.clamp(0.0, 1.0) * plot.width;
  }

  double yOf(num count) => plot.bottom - (count / maxCount) * plot.height;

  /// The bar under a tap, or null outside the plot.
  int? binAt(Offset p) {
    if (p.dx < plot.left || p.dx > plot.right) return null;
    return ((p.dx - plot.left) / binWidth).floor().clamp(0, bins - 1);
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter({
    required this.geometry,
    required this.counts,
    required this.selectedBin,
    required this.progress,
    required this.labelStyle,
    this.placeholder = false,
  });

  final _Geometry geometry;
  final List<int> counts;
  final int? selectedBin;
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

    // Recessive hairlines: baseline, plus the busiest bar's level when
    // there is data to read it against.
    final grid = Paint()
      ..color = AppGlass.divider
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(plot.left, plot.bottom), Offset(plot.right, plot.bottom), grid);
    if (counts.isNotEmpty) {
      canvas.drawLine(Offset(plot.left, g.yOf(g.maxCount)),
          Offset(plot.right, g.yOf(g.maxCount)), grid);
      _text(canvas, '${g.maxCount}', Offset(0, g.yOf(g.maxCount) - 6));
    }
    _text(canvas, '0', Offset(0, plot.bottom - 6));

    // Date labels: start, middle and today.
    final mid = g.start.add(g.end.difference(g.start) ~/ 2);
    String short(DateTime d) => '${DentraDates.monthShort(d.month)} ${d.day}';
    _text(canvas, short(g.start), Offset(plot.left, plot.bottom + 6));
    _text(canvas, short(mid), Offset(g.xOf(mid), plot.bottom + 6),
        center: true);
    _text(canvas, 'Today', Offset(plot.right, plot.bottom + 6),
        alignRight: true);

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

    final bar = Paint()..color = AppColors.g2.withValues(alpha: 0.45);
    final barSelected = Paint()..color = AppColors.g2;
    final guide = Paint()..color = AppColors.g2.withValues(alpha: 0.08);
    final w = (g.binWidth * 0.5).clamp(4.0, 14.0);

    for (var i = 0; i < counts.length; i++) {
      if (counts[i] == 0) continue;
      final x = g.centerOf(i);
      final isSelected = i == selectedBin;
      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(x - g.binWidth / 2 + 1, plot.top,
                x + g.binWidth / 2 - 1, plot.bottom),
            const Radius.circular(6),
          ),
          guide,
        );
      }
      final y = g.yOf(counts[i] * progress);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x - w / 2, y, x + w / 2, plot.bottom),
          topLeft: Radius.circular(w / 2),
          topRight: Radius.circular(w / 2),
        ),
        isSelected ? barSelected : bar,
      );
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
      old.selectedBin != selectedBin ||
      old.counts != counts ||
      old.geometry.size != geometry.size;
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// The tapped bar's screenings, with a way into each one's details.
class _Details extends StatelessWidget {
  const _Details({super.key, required this.title, required this.sessions});

  final String title;
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
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '$title · ${sessions.length} '
              '${sessions.length == 1 ? 'screening' : 'screenings'}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
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
                            s.analysis == null
                                ? 'No analysis saved'
                                : 'Analysis saved',
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
