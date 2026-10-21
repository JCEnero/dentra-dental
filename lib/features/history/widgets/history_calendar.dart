import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';

/// Calendar card: month navigation, plus either a swipeable week strip or
/// (expanded) the full month. Days with screenings carry a dot.
class HistoryCalendar extends StatefulWidget {
  const HistoryCalendar({
    super.key,
    required this.month,
    required this.weekStart,
    required this.selectedDay,
    required this.markedDays,
    required this.canGoBack,
    required this.canGoForward,
    required this.onShiftMonth,
    required this.onShiftWeek,
    required this.onDayTap,
    this.dimmed = false,
    this.earliestMonth,
  });

  final DateTime month;
  final DateTime weekStart;
  final DateTime? selectedDay;

  /// Dates (time stripped) that have at least one screening.
  final Set<DateTime> markedDays;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<int> onShiftMonth;
  final ValueChanged<int> onShiftWeek;
  final ValueChanged<DateTime> onDayTap;

  /// Faded while search or "all time" overrides the calendar.
  final bool dimmed;

  /// First month the full-screen calendar lists; defaults to a year back.
  final DateTime? earliestMonth;

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  bool _expanded = false;

  /// +1 when moving forward in time, -1 backward; drives slide direction.
  int _direction = 1;

  @override
  void didUpdateWidget(HistoryCalendar old) {
    super.didUpdateWidget(old);
    final before = _expanded ? old.month : old.weekStart;
    final after = _expanded ? widget.month : widget.weekStart;
    if (after != before) _direction = after.isAfter(before) ? 1 : -1;
  }

  DateTime get _today => DentraDates.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final motion = dentraMotion(context, 260);

    return AnimatedOpacity(
      duration: dentraMotion(context),
      opacity: widget.dimmed ? 0.55 : 1,
      child: GlassCard(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          children: [
            _MonthBar(
              month: widget.month,
              expanded: _expanded,
              canGoBack: widget.canGoBack,
              canGoForward: widget.canGoForward,
              onShift: widget.onShiftMonth,
              onToggle: () => setState(() => _expanded = !_expanded),
              onFullScreen: () => showCalendarFullScreen(
                context,
                earliestMonth: widget.earliestMonth,
                focusMonth: widget.month,
                selectedDay: widget.selectedDay,
                markedDays: widget.markedDays,
                onDayTap: widget.onDayTap,
              ),
            ),
            const SizedBox(height: 8),
            // Horizontal swipes move by week (strip) or month (grid).
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < 250) return;
                final delta = v < 0 ? 1 : -1;
                if (_expanded) {
                  if (delta > 0 ? widget.canGoForward : widget.canGoBack) {
                    widget.onShiftMonth(delta);
                  }
                } else if (delta < 0 || _canShowWeekAfter()) {
                  widget.onShiftWeek(delta);
                }
              },
              child: AnimatedSize(
                duration: motion,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: motion,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final incoming = child.key ==
                        ValueKey(_expanded ? widget.month : widget.weekStart);
                    final dx = 0.18 * _direction * (incoming ? 1 : -1);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(dx, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  child: _expanded
                      ? _MonthGrid(
                          key: ValueKey(widget.month),
                          month: widget.month,
                          today: _today,
                          selectedDay: widget.selectedDay,
                          markedDays: widget.markedDays,
                          onDayTap: widget.onDayTap,
                        )
                      : _WeekStrip(
                          key: ValueKey(widget.weekStart),
                          weekStart: widget.weekStart,
                          month: widget.month,
                          today: _today,
                          selectedDay: widget.selectedDay,
                          markedDays: widget.markedDays,
                          onDayTap: widget.onDayTap,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Weeks entirely in the future have nothing to show.
  bool _canShowWeekAfter() =>
      !widget.weekStart.add(const Duration(days: 7)).isAfter(_today);
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.expanded,
    required this.canGoBack,
    required this.canGoForward,
    required this.onShift,
    required this.onToggle,
    required this.onFullScreen,
  });

  final DateTime month;
  final bool expanded;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<int> onShift;
  final VoidCallback onToggle;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    final prev = DentraDates.addMonths(month, -1);
    final next = DentraDates.addMonths(month, 1);
    final sideStyle = GoogleFonts.outfit(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.secondaryText,
    );

    Widget arrow(IconData icon, String tip, bool enabled, int delta) =>
        IconButton(
          onPressed: enabled ? () => onShift(delta) : null,
          tooltip: tip,
          icon: Icon(icon, size: 22),
          color: AppColors.navy,
          disabledColor: AppColors.secondaryText.withValues(alpha: 0.3),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        );

    Widget side(DateTime m, bool enabled, int delta) => AnimatedOpacity(
          duration: dentraMotion(context, 180),
          opacity: enabled ? 1 : 0.35,
          child: InkWell(
            onTap: enabled ? () => onShift(delta) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Text(DentraDates.monthShort(m.month), style: sideStyle),
            ),
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Neighbouring month names only when there is room for them.
        final showSides = constraints.maxWidth >= 340;
        return Row(
          children: [
            arrow(Icons.chevron_left_rounded, 'Previous month', canGoBack, -1),
            if (showSides) ExcludeSemantics(child: side(prev, canGoBack, -1)),
            Expanded(
              child: Semantics(
                button: true,
                label: '${DentraDates.monthYear(month)}. '
                    '${expanded ? 'Collapse to week' : 'Expand to full month'}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: dentraMotion(context, 200),
                            child: Text(
                              DentraDates.monthYear(month),
                              key: ValueKey(month),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: dentraMotion(context),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showSides) ExcludeSemantics(child: side(next, canGoForward, 1)),
            arrow(Icons.chevron_right_rounded, 'Next month', canGoForward, 1),
            IconButton(
              onPressed: onFullScreen,
              tooltip: 'Full-screen calendar',
              icon: const Icon(Icons.open_in_full_rounded, size: 18),
              color: AppColors.secondaryText,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        );
      },
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    super.key,
    required this.weekStart,
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.markedDays,
    required this.onDayTap,
  });

  final DateTime weekStart;
  final DateTime month;
  final DateTime today;
  final DateTime? selectedDay;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _DayCell(
              date:
                  DateTime(weekStart.year, weekStart.month, weekStart.day + i),
              showWeekday: true,
              inMonth: DentraDates.sameMonth(
                  DateTime(weekStart.year, weekStart.month, weekStart.day + i),
                  month),
              today: today,
              selectedDay: selectedDay,
              markedDays: markedDays,
              onTap: onDayTap,
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.markedDays,
    required this.onDayTap,
    this.showWeekdays = true,
    this.dense = false,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? selectedDay;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onDayTap;
  final bool showWeekdays;

  /// Small numbers, for the full-screen calendar.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final first = DentraDates.weekStart(month);
    final last = DateTime(month.year, month.month + 1, 0);
    final weeks = (last.difference(first).inDays ~/ 7) + 1;

    return Column(
      children: [
        if (showWeekdays) ...[
          Row(
            children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      DentraDates.weekdayShort(i),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        for (var w = 0; w < weeks; w++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(builder: (context) {
                    final date = DateTime(
                        first.year, first.month, first.day + w * 7 + i);
                    final inMonth = DentraDates.sameMonth(date, month);
                    // Days outside the month leave a blank, keeping the grid.
                    if (!inMonth) return SizedBox(height: dense ? 40 : 48);
                    return _DayCell(
                      date: date,
                      showWeekday: false,
                      dense: dense,
                      inMonth: true,
                      today: today,
                      selectedDay: selectedDay,
                      markedDays: markedDays,
                      onTap: onDayTap,
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.showWeekday,
    required this.inMonth,
    required this.today,
    required this.selectedDay,
    required this.markedDays,
    required this.onTap,
    this.dense = false,
  });

  final DateTime date;
  final bool showWeekday;
  final bool dense;
  final bool inMonth;
  final DateTime today;
  final DateTime? selectedDay;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final selected =
        selectedDay != null && DentraDates.sameDay(date, selectedDay!);
    final isToday = DentraDates.sameDay(date, today);
    final future = date.isAfter(today);
    final marked = markedDays.contains(date);

    final dayColor = selected
        ? AppColors.white
        : future
            ? AppColors.secondaryText.withValues(alpha: 0.4)
            : inMonth
                ? AppColors.navy
                : AppColors.secondaryText.withValues(alpha: 0.6);

    return Semantics(
      button: !future,
      selected: selected,
      enabled: !future,
      label: '${DentraDates.full(date)}'
          '${marked ? ', has history' : ''}'
          '${isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: future ? null : () => onTap(date),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: dentraMotion(context, 200),
              constraints: BoxConstraints(
                  minHeight: showWeekday ? 64 : (dense ? 36 : 44)),
              padding: EdgeInsets.symmetric(vertical: showWeekday ? 8 : 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(dense ? 10 : 14),
                border: isToday && !selected
                    ? Border.all(color: AppColors.g2.withValues(alpha: 0.45))
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showWeekday) ...[
                    Text(
                      DentraDates.weekdayShort(date.weekday),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? AppColors.white.withValues(alpha: 0.75)
                            : AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    '${date.day}',
                    style: GoogleFonts.outfit(
                      fontSize: showWeekday ? 16 : (dense ? 12.5 : 14),
                      fontWeight: dense ? FontWeight.w600 : FontWeight.w700,
                      color: dayColor,
                    ),
                  ),
                  SizedBox(height: dense ? 2 : 3),
                  // Dot for days with history; same height either way.
                  AnimatedOpacity(
                    duration: dentraMotion(context, 160),
                    opacity: marked ? 1 : 0,
                    child: Container(
                      width: dense ? 4 : 5,
                      height: dense ? 4 : 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.white : AppColors.g2,
                      ),
                    ),
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

// ── Full-screen calendar ────────────────────────────────────────────────────

/// Opens every month from [earliestMonth] to this month as a scrolling
/// list of compact grids. Choosing a day closes it and calls [onDayTap].
Future<void> showCalendarFullScreen(
  BuildContext context, {
  required DateTime focusMonth,
  required DateTime? selectedDay,
  required Set<DateTime> markedDays,
  required ValueChanged<DateTime> onDayTap,
  DateTime? earliestMonth,
}) {
  final now = DateTime.now();
  final thisMonth = DentraDates.monthOf(now);
  // At least a year back, so the view never feels empty.
  final yearBack = DentraDates.addMonths(thisMonth, -11);
  final first = earliestMonth == null || earliestMonth.isAfter(yearBack)
      ? yearBack
      : DentraDates.monthOf(earliestMonth);

  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    transitionDuration: dentraMotion(context, 280),
    reverseTransitionDuration: dentraMotion(context, 220),
    pageBuilder: (_, __, ___) => _CalendarFullScreen(
      firstMonth: first,
      lastMonth: thisMonth,
      focusMonth: focusMonth,
      selectedDay: selectedDay,
      markedDays: markedDays,
      onDayTap: onDayTap,
    ),
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  ));
}

class _CalendarFullScreen extends StatefulWidget {
  const _CalendarFullScreen({
    required this.firstMonth,
    required this.lastMonth,
    required this.focusMonth,
    required this.selectedDay,
    required this.markedDays,
    required this.onDayTap,
  });

  final DateTime firstMonth;
  final DateTime lastMonth;
  final DateTime focusMonth;
  final DateTime? selectedDay;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onDayTap;

  @override
  State<_CalendarFullScreen> createState() => _CalendarFullScreenState();
}

class _CalendarFullScreenState extends State<_CalendarFullScreen> {
  late final List<DateTime> _months = [
    for (var m = widget.lastMonth;
        !m.isBefore(widget.firstMonth);
        m = DentraDates.addMonths(m, -1))
      m,
  ];
  late final Map<DateTime, GlobalKey> _keys = {
    for (final m in _months) m: GlobalKey()
  };

  @override
  void initState() {
    super.initState();
    // Open on the month the small calendar was showing.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _reveal(widget.focusMonth));
  }

  void _reveal(DateTime month, {bool animate = false}) {
    final ctx = _keys[DentraDates.monthOf(month)]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: animate ? dentraMotion(context, 320) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  void _pick(DateTime day) {
    Navigator.of(context).pop();
    widget.onDayTap(day);
  }

  @override
  Widget build(BuildContext context) {
    final today = DentraDates.dateOnly(DateTime.now());
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DentraPageHeader(
                title: 'Calendar',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: TextButton(
                  onPressed: () => _reveal(widget.lastMonth, animate: true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.g2,
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    'Today',
                    semanticsLabel: 'Go to this month',
                    style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              // Weekday names once, pinned above every month.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, 8),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 1; i <= 7; i++)
                        Expanded(
                          child: Text(
                            DentraDates.weekdayShort(i).substring(0, 1),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: AppGlass.divider),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      8,
                      AppSpacing.screenH,
                      24 + MediaQuery.paddingOf(context).bottom),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Oldest first, so time runs down the page.
                          for (final m in _months.reversed)
                            _MonthSection(
                              key: _keys[m],
                              month: m,
                              today: today,
                              selectedDay: widget.selectedDay,
                              markedDays: widget.markedDays,
                              onDayTap: _pick,
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.g2,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Days with history',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    super.key,
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.markedDays,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? selectedDay;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final days =
        markedDays.where((d) => DentraDates.sameMonth(d, month)).length;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      DentraDates.monthYear(month),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
                if (days > 0)
                  Text(
                    '$days ${days == 1 ? 'day' : 'days'}',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _MonthGrid(
            month: month,
            today: today,
            selectedDay: selectedDay,
            markedDays: markedDays,
            onDayTap: onDayTap,
            showWeekdays: false,
            dense: true,
          ),
        ],
      ),
    );
  }
}
