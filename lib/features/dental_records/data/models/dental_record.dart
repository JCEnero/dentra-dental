import 'dart:typed_data';

import '../../../dental_explorer/data/tooth_catalog.dart';

/// Where an item in the dental history comes from. Every record keeps
/// its source, and the app never merges them: an AI finding, something a
/// dentist documented (as entered by the user) and the user's own
/// observation stay different kinds of information.
enum RecordSource {
  /// DENTRA's screening pipeline (`screening_sessions` on the server).
  aiScreening(
    'ai_screening',
    'Smart Screening',
    'Smart visual screening result',
  ),

  /// A dental visit the user wrote down. Not verified by DENTRA.
  clinicRecord(
    'clinic_record',
    'Clinic Record',
    'Information you recorded from a dental visit',
  ),
  personalPhoto(
    'personal_photo',
    'Personal Photo',
    'Photo you uploaded',
  ),
  personalNote(
    'personal_note',
    'Personal Note',
    'Note you wrote',
  );

  const RecordSource(this.id, this.label, this.description);

  /// Stable id used by the API.
  final String id;

  /// Short label shown on every record.
  final String label;

  /// One line on what this kind of record is.
  final String description;

  static RecordSource fromId(String id) => values.firstWhere(
        (s) => s.id == id,
        orElse: () => throw FormatException('Unknown record source: $id'),
      );

  /// Sources the user creates and edits themselves.
  static const userEntered = [clinicRecord, personalPhoto, personalNote];
}

/// A clinic visit, personal photo or personal note in the user's history.
/// AI screenings are `ScreeningSession`s, never this.
///
/// JSON matches `/api/dental-records` (`dental_records` table).
class DentalRecord {
  const DentalRecord({
    required this.id,
    required this.source,
    required this.recordDate,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.dateUnknown = false,
    this.clinicName,
    this.dentistName,
    this.procedure,
    this.clinicNotes,
    this.followUpDate,
    this.toothNumbers = const [],
    this.notes,
    this.attachments = const [],
  });

  final String id;
  final RecordSource source;
  final String? title;

  /// Visit date, photo capture date or note date (date only, local).
  final DateTime recordDate;

  /// Photos only: the capture date isn't known, so [recordDate] is the
  /// day the photo was added.
  final bool dateUnknown;

  // Clinic records only.
  final String? clinicName;
  final String? dentistName;
  final String? procedure;

  /// What the clinic documented, as entered by the user.
  final String? clinicNotes;
  final DateTime? followUpDate;

  /// FDI numbers the user chose. Empty when no specific tooth.
  final List<String> toothNumbers;

  /// The user's own words: note text, photo description or visit notes.
  final String? notes;
  final List<RecordAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<RecordAttachment> get images =>
      attachments.where((a) => a.isImage).toList();

  List<RecordAttachment> get documents =>
      attachments.where((a) => !a.isImage).toList();

  /// Title for lists: the user's own, else a sensible one from the fields.
  String get displayTitle {
    final own = title?.trim();
    if (own != null && own.isNotEmpty) return own;
    return switch (source) {
      RecordSource.clinicRecord => procedure ?? clinicName ?? 'Clinic visit',
      RecordSource.personalPhoto => 'Personal photo',
      RecordSource.personalNote => _firstLine(notes) ?? 'Personal note',
      RecordSource.aiScreening => 'Dental screening',
    };
  }

  /// Tooth numbers the chart knows, as ints.
  List<int> get teeth => [
        for (final t in toothNumbers)
          if (int.tryParse(t) case final n? when ToothCatalog.byFdi(n) != null) n,
      ];

  static String? _firstLine(String? text) {
    final line = text?.trim().split('\n').first.trim();
    if (line == null || line.isEmpty) return null;
    return line.length > 60 ? '${line.substring(0, 57)}…' : line;
  }

  DentalRecord copyWith({List<RecordAttachment>? attachments}) => DentalRecord(
        id: id,
        source: source,
        recordDate: recordDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        title: title,
        dateUnknown: dateUnknown,
        clinicName: clinicName,
        dentistName: dentistName,
        procedure: procedure,
        clinicNotes: clinicNotes,
        followUpDate: followUpDate,
        toothNumbers: toothNumbers,
        notes: notes,
        attachments: attachments ?? this.attachments,
      );

  factory DentalRecord.fromJson(Map<String, dynamic> json) => DentalRecord(
        id: json['id'] as String,
        source: RecordSource.fromId(json['source'] as String),
        title: json['title'] as String?,
        recordDate: parseDay(json['record_date'] as String),
        dateUnknown: json['date_unknown'] as bool? ?? false,
        clinicName: json['clinic_name'] as String?,
        dentistName: json['dentist_name'] as String?,
        procedure: json['procedure'] as String?,
        clinicNotes: json['clinic_notes'] as String?,
        followUpDate: json['follow_up_date'] == null
            ? null
            : parseDay(json['follow_up_date'] as String),
        toothNumbers:
            ((json['tooth_numbers'] as List<dynamic>?) ?? const []).cast<String>(),
        notes: json['notes'] as String?,
        attachments: ((json['attachments'] as List<dynamic>?) ?? const [])
            .map((e) => RecordAttachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source.id,
        'title': title,
        'record_date': formatDay(recordDate),
        'date_unknown': dateUnknown,
        'clinic_name': clinicName,
        'dentist_name': dentistName,
        'procedure': procedure,
        'clinic_notes': clinicNotes,
        'follow_up_date': followUpDate == null ? null : formatDay(followUpDate!),
        'tooth_numbers': toothNumbers,
        'notes': notes,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

/// A photo or PDF the user attached to a record. Always user-provided:
/// DENTRA does not verify uploaded documents.
class RecordAttachment {
  const RecordAttachment({
    required this.id,
    required this.kind,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
    this.fileName,
    this.url,
    this.bytes,
  });

  final String id;

  /// 'image' or 'document' (PDF).
  final String kind;
  final String contentType;
  final String? fileName;
  final int sizeBytes;
  final DateTime uploadedAt;

  /// Short-lived signed link from the API.
  final String? url;

  /// Kept in memory instead of [url] by the on-device store.
  final Uint8List? bytes;

  bool get isImage => kind == 'image';

  factory RecordAttachment.fromJson(Map<String, dynamic> json) =>
      RecordAttachment(
        id: json['id'] as String,
        kind: json['kind'] as String,
        contentType: json['content_type'] as String,
        fileName: json['file_name'] as String?,
        sizeBytes: json['size_bytes'] as int? ?? 0,
        uploadedAt: DateTime.parse(json['uploaded_at'] as String).toLocal(),
        url: json['url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'content_type': contentType,
        'file_name': fileName,
        'size_bytes': sizeBytes,
        'uploaded_at': uploadedAt.toUtc().toIso8601String(),
        'url': url,
      };
}

/// What the add/edit forms submit. Fields that don't belong to [source]
/// are left out of the request.
class DentalRecordInput {
  const DentalRecordInput({
    required this.source,
    required this.recordDate,
    this.title,
    this.dateUnknown = false,
    this.clinicName,
    this.dentistName,
    this.procedure,
    this.clinicNotes,
    this.followUpDate,
    this.toothNumbers = const [],
    this.notes,
  }) : assert(source != RecordSource.aiScreening);

  final RecordSource source;
  final DateTime recordDate;
  final String? title;
  final bool dateUnknown;
  final String? clinicName;
  final String? dentistName;
  final String? procedure;
  final String? clinicNotes;
  final DateTime? followUpDate;
  final List<String> toothNumbers;
  final String? notes;

  /// Body for create, and for update (all editable fields at once).
  Map<String, dynamic> toJson({bool includeSource = true}) => {
        if (includeSource) 'source': source.id,
        'title': _blankToNull(title),
        'record_date': formatDay(recordDate),
        'tooth_numbers': toothNumbers,
        'notes': _blankToNull(notes),
        if (source == RecordSource.personalPhoto) 'date_unknown': dateUnknown,
        if (source == RecordSource.clinicRecord) ...{
          'clinic_name': _blankToNull(clinicName),
          'dentist_name': _blankToNull(dentistName),
          'procedure': _blankToNull(procedure),
          'clinic_notes': _blankToNull(clinicNotes),
          'follow_up_date':
              followUpDate == null ? null : formatDay(followUpDate!),
        },
      };

  static String? _blankToNull(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}

/// "2026-10-21" -> a local date at midnight.
DateTime parseDay(String value) {
  final d = DateTime.parse(value);
  return DateTime(d.year, d.month, d.day);
}

String formatDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';
