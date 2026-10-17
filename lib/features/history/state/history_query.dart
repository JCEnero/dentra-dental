import '../../../core/utils/dentra_dates.dart';
import '../../scan/data/scan_regions.dart';
import '../../screening/data/models/screening_session.dart';

enum HistorySort {
  newest('Newest first'),
  oldest('Oldest first');

  const HistorySort(this.label);
  final String label;
}

/// Which dates the list covers when nothing is being searched.
enum HistoryScope {
  /// The month (or day) chosen on the calendar.
  calendar('Calendar selection'),
  allTime('All time');

  const HistoryScope(this.label);
  final String label;
}

/// Filters from the filter sheet. Empty sets mean "any".
class HistoryFilters {
  const HistoryFilters({
    this.scope = HistoryScope.calendar,
    this.statuses = const {},
    this.regions = const {},
    this.sort = HistorySort.newest,
  });

  final HistoryScope scope;
  final Set<ScreeningStatus> statuses;

  /// Region ids; a session matches if it captured any of them.
  final Set<String> regions;
  final HistorySort sort;

  static const defaults = HistoryFilters();

  /// Number of non-default choices, for the filter button badge.
  int get activeCount =>
      (scope != HistoryScope.calendar ? 1 : 0) +
      (statuses.isNotEmpty ? 1 : 0) +
      (regions.isNotEmpty ? 1 : 0) +
      (sort != HistorySort.newest ? 1 : 0);

  bool get isDefault => activeCount == 0;

  HistoryFilters copyWith({
    HistoryScope? scope,
    Set<ScreeningStatus>? statuses,
    Set<String>? regions,
    HistorySort? sort,
  }) =>
      HistoryFilters(
        scope: scope ?? this.scope,
        statuses: statuses ?? this.statuses,
        regions: regions ?? this.regions,
        sort: sort ?? this.sort,
      );
}

/// Everything that decides which records the list shows.
class HistoryViewState {
  const HistoryViewState({
    required this.month,
    required this.weekStart,
    this.day,
    this.query = '',
    this.filters = HistoryFilters.defaults,
  });

  /// First day of the month shown on the calendar.
  final DateTime month;

  /// Monday of the week shown in the collapsed calendar strip.
  final DateTime weekStart;

  /// Selected day, or null for the whole month.
  final DateTime? day;
  final String query;
  final HistoryFilters filters;

  bool get isSearching => query.trim().isNotEmpty;

  /// Search and "all time" look across every date; otherwise the calendar
  /// selection applies.
  bool get usesCalendar =>
      !isSearching && filters.scope == HistoryScope.calendar;

  HistoryViewState copyWith({
    DateTime? month,
    DateTime? weekStart,
    DateTime? Function()? day,
    String? query,
    HistoryFilters? filters,
  }) =>
      HistoryViewState(
        month: month ?? this.month,
        weekStart: weekStart ?? this.weekStart,
        day: day != null ? day() : this.day,
        query: query ?? this.query,
        filters: filters ?? this.filters,
      );
}

/// Applies the calendar, search, filters and sort to [sessions].
///
/// Pure, so it is easy to test and mirrors what an API query would do:
/// date range -> WHERE completed_at, status/regions -> WHERE, sort ->
/// ORDER BY completed_at.
List<ScreeningSession> applyHistoryQuery(
  List<ScreeningSession> sessions,
  HistoryViewState view,
) {
  final f = view.filters;
  final terms = view.query
      .toLowerCase()
      .split(RegExp(r'[\s,]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  final result = sessions.where((s) {
    final at = s.completedAt;
    if (view.usesCalendar) {
      if (view.day != null) {
        if (!DentraDates.sameDay(at, view.day!)) return false;
      } else if (!DentraDates.sameMonth(at, view.month)) {
        return false;
      }
    }
    if (f.statuses.isNotEmpty && !f.statuses.contains(s.status)) return false;
    if (f.regions.isNotEmpty && !s.capturedRegions.any(f.regions.contains)) {
      return false;
    }
    if (terms.isNotEmpty) {
      final haystack = searchableText(s);
      if (!terms.every(haystack.contains)) return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => f.sort == HistorySort.newest
        ? b.completedAt.compareTo(a.completedAt)
        : a.completedAt.compareTo(b.completedAt));
  return result;
}

/// Lower-case text a search can match: dates in several spellings, the
/// time, captured region names and status.
String searchableText(ScreeningSession s) {
  final d = s.completedAt;
  final regions = s.capturedRegions
      .map((id) => scanRegions.where((r) => r.id == id).firstOrNull?.label)
      .whereType<String>();
  return [
    DentraDates.full(d),
    DentraDates.medium(d),
    '${d.month}/${d.day}/${d.year}',
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    DentraDates.time(d),
    ...regions,
    s.status.label,
    s.analysis != null ? 'analyzed ai analysis' : '',
  ].join(' ').toLowerCase();
}
