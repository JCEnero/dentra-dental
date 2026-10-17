import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
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
  });

  final DateTime month;
  final bool expanded;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<int> onShift;
  final VoidCallback onToggle;

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
        final showSides = constraints.maxWidth >= 300;
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
              date: DateTime(weekStart.year, weekStart.month, weekStart.day + i),
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
  });

  final DateTime month;
  final DateTime today;
  final DateTime? selectedDay;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final first = DentraDates.weekStart(month);
    final last = DateTime(month.year, month.month + 1, 0);
    final weeks = (last.difference(first).inDays ~/ 7) + 1;

    return Column(
      children: [
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
        for (var w = 0; w < weeks; w++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(builder: (context) {
                    final date =
                        DateTime(first.year, first.month, first.day + w * 7 + i);
                    final inMonth = DentraDates.sameMonth(date, month);
                    // Days outside the month leave a blank, keeping the grid.
                    if (!inMonth) return const SizedBox(height: 48);
                    return _DayCell(
                      date: date,
                      showWeekday: false,
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
  });

  final DateTime date;
  final bool showWeekday;
  final bool inMonth;
  final DateTime today;
  final DateTime? selectedDay;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectedDay != null && DentraDates.sameDay(date, selectedDay!);
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
          '${marked ? ', has screenings' : ''}'
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
              constraints: BoxConstraints(minHeight: showWeekday ? 64 : 44),
              padding: EdgeInsets.symmetric(vertical: showWeekday ? 8 : 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
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
                      fontSize: showWeekday ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: dayColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Dot for days with screenings; same height either way.
                  AnimatedOpacity(
                    duration: dentraMotion(context, 160),
                    opacity: marked ? 1 : 0,
                    child: Container(
                      width: 5,
                      height: 5,
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
