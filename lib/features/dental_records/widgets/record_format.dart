import 'package:flutter/painting.dart';

import '../../../core/utils/dentra_dates.dart';
import '../data/models/dental_record.dart';

// Display text shared by the timeline, detail page, comparison and tooth
// history, so a record reads the same everywhere.

/// "Sep 14, 2026", or for a photo with no known date, when it was added.
String recordDateLabel(DentalRecord r) => r.dateUnknown
    ? 'Date taken unknown · added ${DentraDates.medium(r.recordDate)}'
    : DentraDates.long(r.recordDate);

/// The most useful second line for a record, if any.
String? recordDetailLine(DentalRecord r) {
  String? firstLine(String? t) {
    final line = t?.trim().split('\n').first.trim();
    return line == null || line.isEmpty ? null : line;
  }

  return switch (r.source) {
    RecordSource.clinicRecord => [
        if (r.clinicName != null && r.displayTitle != r.clinicName)
          r.clinicName!,
        if (r.dentistName != null) r.dentistName!,
      ].join(' · ').ifEmpty(firstLine(r.clinicNotes)),
    RecordSource.personalPhoto => firstLine(r.notes),
    // The title already is the note's first line unless one was given.
    RecordSource.personalNote => r.title == null ? null : firstLine(r.notes),
    RecordSource.aiScreening => null,
  };
}

/// "Tooth 26" or "Teeth 26, 36".
String teethLabel(List<String> teeth) =>
    '${teeth.length == 1 ? 'Tooth' : 'Teeth'} ${teeth.join(', ')}';

/// The image to show for an attachment: the signed link, or the bytes the
/// on-device store keeps.
ImageProvider? attachmentImage(RecordAttachment a) {
  if (!a.isImage) return null;
  if (a.bytes != null) return MemoryImage(a.bytes!);
  if (a.url != null) return NetworkImage(a.url!);
  return null;
}

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}
