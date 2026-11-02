import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dentra_dates.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../dental_records/widgets/record_format.dart';
import '../../history/state/history_entry.dart';
import '../../scan/data/scan_regions.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';

/// One image a compared record can show.
class ComparableImage {
  const ComparableImage({
    required this.label,
    required this.image,
    this.regionId,
  });

  /// e.g. "Upper left" for a screening region, "Photo" for a personal photo.
  final String label;
  final ImageProvider image;

  /// Screening region, so two screenings can be matched region by region.
  final String? regionId;
}

/// A saved record that can be compared: any AI screening, plus personal
/// photos and clinic records that have photos. Notes have nothing to
/// compare side by side, so they aren't offered.
class ComparableItem {
  const ComparableItem({required this.entry, required this.images});

  final HistoryEntry entry;
  final List<ComparableImage> images;

  String get key => entry.key;
  RecordSource get source => entry.source;
  DateTime get at => entry.at;
  DateTime get day => entry.day;

  ScreeningSession? get screening =>
      entry is ScreeningEntry ? (entry as ScreeningEntry).session : null;
  DentalRecord? get record =>
      entry is RecordEntry ? (entry as RecordEntry).record : null;

  String get title {
    final s = screening;
    if (s != null) {
      return 'Dental screening · ${s.capturedViewCount} of '
          '${s.totalRegions} views';
    }
    return record!.displayTitle;
  }

  /// Time for screenings; records only have a date.
  String get when {
    final s = screening;
    if (s != null) return DentraDates.time(s.completedAt);
    return record!.dateUnknown ? 'Date taken unknown' : 'Date only';
  }
}

/// Everything the user can compare, newest first. Screening photos come
/// from storage links, or from this app run's memory before upload.
final comparableItemsProvider = Provider<AsyncValue<List<ComparableItem>>>((ref) {
  final cache = ref.watch(screeningImageCacheProvider);
  return ref.watch(historyEntriesProvider).whenData((entries) => [
        for (final e in entries)
          if (_itemFor(e, cache) case final item?) item,
      ]);
});

ComparableItem? _itemFor(
  HistoryEntry e,
  Map<String, Map<String, Uint8List>> cache,
) {
  switch (e) {
    case ScreeningEntry(:final session):
      final local = cache[session.id] ?? const {};
      return ComparableItem(entry: e, images: [
        for (final id in session.capturedRegions)
          if (local[id] != null)
            ComparableImage(
              label: scanRegionById(id).label,
              image: MemoryImage(local[id]!),
              regionId: id,
            )
          else if (session.captureFor(id)?.imageUrl case final url?)
            ComparableImage(
              label: scanRegionById(id).label,
              image: NetworkImage(url),
              regionId: id,
            ),
      ]);
    case RecordEntry(:final record):
      if (record.source == RecordSource.personalNote) return null;
      final images = [
        for (final (i, a) in record.images.indexed)
          if (attachmentImage(a) case final image?)
            ComparableImage(
              label: record.source == RecordSource.personalPhoto
                  ? 'Photo'
                  : a.fileName ?? 'Clinic photo ${i + 1}',
              image: image,
            ),
      ];
      return images.isEmpty ? null : ComparableItem(entry: e, images: images);
  }
}

enum ComparisonSlot {
  earlier('Earlier'),
  later('Later');

  const ComparisonSlot(this.label);
  final String label;

  ComparisonSlot get other =>
      this == ComparisonSlot.earlier ? ComparisonSlot.later : ComparisonSlot.earlier;
}

/// The two dates and records the user chose, and whether the result is
/// showing. Kept while the page is open, so either date can change
/// without starting over.
class ComparisonSelection {
  const ComparisonSelection({
    this.earlierDay,
    this.laterDay,
    this.earlierKey,
    this.laterKey,
    this.showingResult = false,
  });

  final DateTime? earlierDay;
  final DateTime? laterDay;
  final String? earlierKey;
  final String? laterKey;
  final bool showingResult;

  DateTime? dayOf(ComparisonSlot slot) =>
      slot == ComparisonSlot.earlier ? earlierDay : laterDay;
  String? keyOf(ComparisonSlot slot) =>
      slot == ComparisonSlot.earlier ? earlierKey : laterKey;

  bool get canCompare =>
      earlierKey != null && laterKey != null && earlierKey != laterKey;

  ComparisonSelection copyWithSlot(
    ComparisonSlot slot, {
    required DateTime? day,
    required String? key,
  }) =>
      slot == ComparisonSlot.earlier
          ? ComparisonSelection(
              earlierDay: day,
              earlierKey: key,
              laterDay: laterDay,
              laterKey: laterKey,
              showingResult: showingResult,
            )
          : ComparisonSelection(
              earlierDay: earlierDay,
              earlierKey: earlierKey,
              laterDay: day,
              laterKey: key,
              showingResult: showingResult,
            );

  ComparisonSelection withResult(bool showing) => ComparisonSelection(
        earlierDay: earlierDay,
        laterDay: laterDay,
        earlierKey: earlierKey,
        laterKey: laterKey,
        showingResult: showing,
      );
}

/// Items saved on [day] (local date), oldest first.
List<ComparableItem> itemsOnDay(List<ComparableItem> all, DateTime day) =>
    all.where((i) => DentraDates.sameDay(i.day, day)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));

/// Days the user can choose for [slot]: only days with saved items, in
/// order with the other slot's day. The same day works when it has
/// another item to compare with.
List<DateTime> selectableDays(
  List<ComparableItem> all,
  ComparisonSelection sel,
  ComparisonSlot slot,
) {
  final counts = <DateTime, int>{};
  for (final i in all) {
    counts.update(i.day, (n) => n + 1, ifAbsent: () => 1);
  }
  final other = sel.dayOf(slot.other);
  return counts.keys.where((d) {
    if (other == null) return true;
    if (DentraDates.sameDay(d, other)) return counts[d]! >= 2;
    return slot == ComparisonSlot.earlier ? d.isBefore(other) : d.isAfter(other);
  }).toList()
    ..sort((a, b) => b.compareTo(a));
}

class ComparisonController extends AutoDisposeNotifier<ComparisonSelection> {
  @override
  ComparisonSelection build() => const ComparisonSelection();

  /// Chooses [day] for [slot]. A day with a single candidate selects it.
  void setDay(ComparisonSlot slot, DateTime day, List<ComparableItem> all) {
    final otherKey = state.keyOf(slot.other);
    final candidates =
        itemsOnDay(all, day).where((i) => i.key != otherKey).toList();
    state = state.copyWithSlot(
      slot,
      day: day,
      key: candidates.length == 1 ? candidates.single.key : null,
    );
    if (state.keyOf(slot) == null) state = state.withResult(false);
  }

  void setItem(ComparisonSlot slot, String key) {
    if (key == state.keyOf(slot.other)) return;
    state = state.copyWithSlot(slot, day: state.dayOf(slot), key: key);
  }

  void showResult() {
    if (state.canCompare) state = state.withResult(true);
  }

  void editSelection() => state = state.withResult(false);

  /// Drops choices whose records were deleted meanwhile.
  void prune(List<ComparableItem> all) {
    final keys = {for (final i in all) i.key};
    var next = state;
    for (final slot in ComparisonSlot.values) {
      final key = next.keyOf(slot);
      if (key != null && !keys.contains(key)) {
        next = next.copyWithSlot(slot, day: next.dayOf(slot), key: null).withResult(false);
      }
    }
    if (!identical(next, state)) state = next;
  }
}

final comparisonControllerProvider =
    NotifierProvider.autoDispose<ComparisonController, ComparisonSelection>(
  ComparisonController.new,
);
