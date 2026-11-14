import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dentra_dates.dart';
import '../../dental_explorer/data/tooth_catalog.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../dental_records/providers/dental_records_provider.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';

/// One item on the dental history timeline. A thin view over the stored
/// record: it never changes or combines what the record says, and its
/// [source] is always the record's own.
sealed class HistoryEntry {
  const HistoryEntry();

  String get key;
  RecordSource get source;

  /// When it happened, for ordering. Records only have a date, so their
  /// time of day comes from when they were added.
  DateTime get at;

  DateTime get day => DentraDates.dateOnly(at);

  /// FDI numbers this item is about. Only what the record states: a
  /// screening counts a tooth only when an AI finding names it.
  Set<int> get teeth;
}

class ScreeningEntry extends HistoryEntry {
  const ScreeningEntry(this.session);

  final ScreeningSession session;

  @override
  String get key => 'screening:${session.id}';

  @override
  RecordSource get source => RecordSource.aiScreening;

  @override
  DateTime get at => session.completedAt;

  @override
  Set<int> get teeth => {
        for (final f
            in session.analysis?.findings ?? const <ScreeningFinding>[])
          if (int.tryParse(f.tooth?.trim() ?? '') case final n?
              when ToothCatalog.byFdi(n) != null)
            n,
      };
}

class RecordEntry extends HistoryEntry {
  const RecordEntry(this.record);

  final DentalRecord record;

  @override
  String get key => 'record:${record.id}';

  @override
  RecordSource get source => record.source;

  @override
  DateTime get at {
    final d = record.recordDate;
    final c = record.createdAt;
    return DateTime(d.year, d.month, d.day, c.hour, c.minute, c.second);
  }

  @override
  Set<int> get teeth => record.teeth.toSet();
}

/// Newest first.
int compareEntries(HistoryEntry a, HistoryEntry b) => b.at.compareTo(a.at);

/// Screenings and records merged into one timeline, newest first.
///
/// Loads when both have answered. If only the records fail, screenings
/// still show (the page offers a retry for the rest); a screening failure
/// is an error, as before.
final historyEntriesProvider = Provider<AsyncValue<List<HistoryEntry>>>((ref) {
  final screenings = ref.watch(screeningSessionsProvider);
  final records = ref.watch(dentalRecordsProvider);

  if (screenings.hasError && !screenings.hasValue) {
    return AsyncError(screenings.error!, screenings.stackTrace!);
  }
  if (!screenings.hasValue || (records.isLoading && !records.hasValue)) {
    return const AsyncLoading();
  }
  return AsyncData([
    for (final s in screenings.requireValue) ScreeningEntry(s),
    for (final r in records.valueOrNull ?? const <DentalRecord>[])
      RecordEntry(r),
  ]..sort(compareEntries));
});

/// Everything on the timeline that concerns tooth [fdi], newest first.
final toothHistoryProvider =
    Provider.family<AsyncValue<List<HistoryEntry>>, int>((ref, fdi) {
  return ref
      .watch(historyEntriesProvider)
      .whenData((all) => all.where((e) => e.teeth.contains(fdi)).toList());
});

/// Teeth with at least one history item, for marking the dental chart.
final teethWithHistoryProvider = Provider<Set<int>>((ref) {
  final all = ref.watch(historyEntriesProvider).valueOrNull ?? const [];
  return {for (final e in all) ...e.teeth};
});
