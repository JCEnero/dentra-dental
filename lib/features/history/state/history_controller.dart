import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dentra_dates.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import 'history_query.dart';

/// Calendar position, search and filters for the History tab.
class HistoryController extends Notifier<HistoryViewState> {
  @override
  HistoryViewState build() {
    final now = DateTime.now();
    return HistoryViewState(
      month: DentraDates.monthOf(now),
      weekStart: DentraDates.weekStart(now),
    );
  }

  /// Shows [month] and a sensible week inside it: the week of its latest
  /// screening, today's week for the current month, else the first week.
  void goToMonth(DateTime month, {List<ScreeningSession> sessions = const []}) {
    final m = DentraDates.monthOf(month);
    final now = DateTime.now();
    final inMonth =
        sessions.where((s) => DentraDates.sameMonth(s.completedAt, m));
    final anchor = inMonth.isNotEmpty
        ? inMonth
            .map((s) => s.completedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        : DentraDates.sameMonth(now, m)
            ? now
            : m;
    state = state.copyWith(
      month: m,
      weekStart: DentraDates.weekStart(anchor),
      day: () => null,
    );
  }

  void shiftMonth(int delta, {List<ScreeningSession> sessions = const []}) =>
      goToMonth(DentraDates.addMonths(state.month, delta), sessions: sessions);

  /// Moves the week strip; the month follows when the week crosses over.
  void shiftWeek(int delta) {
    final start = state.weekStart.add(Duration(days: 7 * delta));
    // The month a week "belongs to" is the one holding its Thursday, so a
    // week split across months lands on the side with more of its days.
    final month = DentraDates.monthOf(start.add(const Duration(days: 3)));
    state = state.copyWith(
      weekStart: start,
      month: month,
      day: () => state.day != null && DentraDates.sameMonth(state.day!, month)
          ? state.day
          : null,
    );
  }

  /// Selects [day]; selecting it again goes back to the whole month.
  void toggleDay(DateTime day) {
    final d = DentraDates.dateOnly(day);
    if (state.day != null && DentraDates.sameDay(state.day!, d)) {
      state = state.copyWith(day: () => null);
      return;
    }
    state = state.copyWith(
      day: () => d,
      month: DentraDates.monthOf(d),
      weekStart: DentraDates.weekStart(d),
    );
  }

  void clearDay() => state = state.copyWith(day: () => null);

  void setQuery(String query) => state = state.copyWith(query: query);

  void setFilters(HistoryFilters filters) =>
      state = state.copyWith(filters: filters);

  /// Back to the default view: no search, default filters, whole month.
  void resetFilters() => state = state.copyWith(
        query: '',
        filters: HistoryFilters.defaults,
        day: () => null,
      );
}

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryViewState>(HistoryController.new);

/// The records the list shows, recomputed when history or the view changes.
final historyResultsProvider =
    Provider<AsyncValue<List<ScreeningSession>>>((ref) {
  final view = ref.watch(historyControllerProvider);
  return ref
      .watch(screeningSessionsProvider)
      .whenData((all) => applyHistoryQuery(all, view));
});
