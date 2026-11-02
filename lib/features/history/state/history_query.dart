import '../../../core/utils/dentra_dates.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../scan/data/scan_regions.dart';
import '../../screening/data/models/screening_session.dart';
import 'history_entry.dart';

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
    this.sources = const {},
    this.statuses = const {},
    this.regions = const {},
    this.sort = HistorySort.newest,
  });

  final HistoryScope scope;

  /// Record sources to show (AI screening, clinic record, ...).
  final Set<RecordSource> sources;

  /// Screening-only filters: while set, only AI screenings match.
  final Set<ScreeningStatus> statuses;

  /// Region ids; a session matches if it captured any of them.
  final Set<String> regions;
  final HistorySort sort;

  static const defaults = HistoryFilters();

  /// Number of non-default choices, for the filter button badge.
  int get activeCount =>
      (scope != HistoryScope.calendar ? 1 : 0) +
      (sources.isNotEmpty ? 1 : 0) +
      (statuses.isNotEmpty ? 1 : 0) +
      (regions.isNotEmpty ? 1 : 0) +
      (sort != HistorySort.newest ? 1 : 0);

  bool get isDefault => activeCount == 0;

  bool get usesScreeningFilters => statuses.isNotEmpty || regions.isNotEmpty;

  HistoryFilters copyWith({
    HistoryScope? scope,
    Set<RecordSource>? sources,
    Set<ScreeningStatus>? statuses,
    Set<String>? regions,
    HistorySort? sort,
  }) =>
      HistoryFilters(
        scope: scope ?? this.scope,
        sources: sources ?? this.sources,
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

/// Applies the calendar, search, filters and sort to the timeline.
///
/// Pure, so it is easy to test and mirrors what an API query would do:
/// date range -> WHERE date, source -> WHERE source, status/regions ->
/// WHERE (screenings only), sort -> ORDER BY date.
List<HistoryEntry> applyHistoryQuery(
  List<HistoryEntry> entries,
  HistoryViewState view,
) {
  final f = view.filters;
  final terms = view.query
      .toLowerCase()
      .split(RegExp(r'[\s,]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  final result = entries.where((e) {
    final at = e.at;
    if (view.usesCalendar) {
      if (view.day != null) {
        if (!DentraDates.sameDay(at, view.day!)) return false;
      } else if (!DentraDates.sameMonth(at, view.month)) {
        return false;
      }
    }
    if (f.sources.isNotEmpty && !f.sources.contains(e.source)) return false;
    if (f.usesScreeningFilters) {
      if (e is! ScreeningEntry) return false;
      final s = e.session;
      if (f.statuses.isNotEmpty && !f.statuses.contains(s.status)) return false;
      if (f.regions.isNotEmpty && !s.capturedRegions.any(f.regions.contains)) {
        return false;
      }
    }
    if (terms.isNotEmpty) {
      final haystack = switch (e) {
        ScreeningEntry(:final session) => searchableText(session),
        RecordEntry(:final record) => searchableRecordText(record),
      };
      if (!terms.every(haystack.contains)) return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => f.sort == HistorySort.newest
        ? b.at.compareTo(a.at)
        : a.at.compareTo(b.at));
  return result;
}

/// Date spellings a search can match.
List<String> _dateTerms(DateTime d) => [
      DentraDates.full(d),
      DentraDates.medium(d),
      '${d.month}/${d.day}/${d.year}',
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    ];

/// Lower-case text a search can match: dates in several spellings, the
/// time, captured region names, status, source and AI-named teeth.
String searchableText(ScreeningSession s) {
  final d = s.completedAt;
  final regions = s.capturedRegions
      .map((id) => findScanRegion(id)?.label)
      .whereType<String>();
  return [
    ..._dateTerms(d),
    DentraDates.time(d),
    ...regions,
    s.status.label,
    RecordSource.aiScreening.label,
    s.analysis != null ? 'analyzed ai analysis' : '',
    for (final f in s.analysis?.findings ?? const <ScreeningFinding>[])
      if (f.tooth != null) 'tooth ${f.tooth}',
  ].join(' ').toLowerCase();
}

/// Lower-case text a search can match for a clinic visit, photo or note.
String searchableRecordText(DentalRecord r) => [
      ..._dateTerms(r.recordDate),
      r.source.label,
      r.displayTitle,
      r.clinicName,
      r.dentistName,
      r.procedure,
      r.clinicNotes,
      r.notes,
      for (final t in r.toothNumbers) 'tooth $t',
    ].whereType<String>().join(' ').toLowerCase();
