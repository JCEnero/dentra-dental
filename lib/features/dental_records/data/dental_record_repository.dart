import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import 'models/dental_record.dart';

/// Data access for clinic visits, personal photos and personal notes.
///
/// `ApiDentalRecordRepository` backs it when the DENTRA backend is
/// configured, [LocalDentalRecordRepository] otherwise (demo mode and
/// tests); see `dentalRecordRepositoryProvider`.
abstract class DentalRecordRepository {
  /// Every record for [userId], newest first.
  Future<List<DentalRecord>> fetchAll(String userId);

  /// One record, with fresh attachment links.
  Future<DentalRecord> fetch(String userId, String id);

  Future<DentalRecord> create(String userId, DentalRecordInput input);

  Future<DentalRecord> update(String userId, String id, DentalRecordInput input);

  Future<void> delete(String userId, String id);

  /// Attaches a JPEG/PNG/WebP photo or a PDF and returns the record.
  Future<DentalRecord> addAttachment(
    String userId,
    String id,
    Uint8List bytes, {
    String? fileName,
  });

  Future<DentalRecord> removeAttachment(
    String userId,
    String id,
    String attachmentId,
  );
}

/// Newest first: record date, then the order records were added.
int compareRecords(DentalRecord a, DentalRecord b) {
  final byDate = b.recordDate.compareTo(a.recordDate);
  return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
}

/// [DentalRecordRepository] backed by the DENTRA API
/// (`/api/dental-records`). The server scopes every call to the token's
/// user, so [userId] arguments are only kept for the interface.
class ApiDentalRecordRepository implements DentalRecordRepository {
  ApiDentalRecordRepository(this._api);

  final ApiClient _api;

  static const _path = '/api/dental-records';

  /// Pages are followed up to this many records, plenty for a personal
  /// history.
  static const _maxRecords = 2000;

  @override
  Future<List<DentalRecord>> fetchAll(String userId) async {
    final records = <DentalRecord>[];
    String? cursor;
    do {
      final body = await _api.send('GET', _path, query: {
        'limit': '200',
        if (cursor != null) 'cursor': cursor,
      });
      records.addAll([
        for (final item in body['items'] as List<dynamic>)
          _recordFrom(item as Map<String, dynamic>),
      ]);
      cursor = body['next_cursor'] as String?;
    } while (cursor != null && records.length < _maxRecords);
    return records;
  }

  @override
  Future<DentalRecord> fetch(String userId, String id) async =>
      _unwrap(await _api.send('GET', '$_path/${Uri.encodeComponent(id)}'));

  @override
  Future<DentalRecord> create(String userId, DentalRecordInput input) async =>
      _unwrap(await _api.send('POST', _path, json: input.toJson()));

  @override
  Future<DentalRecord> update(
    String userId,
    String id,
    DentalRecordInput input,
  ) async =>
      _unwrap(await _api.send(
        'PATCH',
        '$_path/${Uri.encodeComponent(id)}',
        json: input.toJson(includeSource: false),
      ));

  @override
  Future<void> delete(String userId, String id) =>
      _api.send('DELETE', '$_path/${Uri.encodeComponent(id)}');

  @override
  Future<DentalRecord> addAttachment(
    String userId,
    String id,
    Uint8List bytes, {
    String? fileName,
  }) async =>
      _unwrap(await _api.send(
        'POST',
        '$_path/${Uri.encodeComponent(id)}/attachments',
        query: {if (fileName != null) 'name': fileName},
        bytes: bytes,
        contentType: fileContentType(bytes),
      ));

  @override
  Future<DentalRecord> removeAttachment(
    String userId,
    String id,
    String attachmentId,
  ) async =>
      _unwrap(await _api.send(
        'DELETE',
        '$_path/${Uri.encodeComponent(id)}/attachments/'
            '${Uri.encodeComponent(attachmentId)}',
      ));

  DentalRecord _unwrap(Map<String, dynamic> body) =>
      _recordFrom(body['record'] as Map<String, dynamic>);

  /// Attachment links come back relative to the API in development storage.
  DentalRecord _recordFrom(Map<String, dynamic> json) {
    for (final a in ((json['attachments'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()) {
      final url = a['url'] as String?;
      if (url != null) a['url'] = _api.resolve(url);
    }
    return DentalRecord.fromJson(json);
  }
}

/// Content type for an upload, from its first bytes.
String fileContentType(Uint8List bytes) {
  final image = imageContentType(bytes);
  if (image != 'application/octet-stream') return image;
  final isPdf = bytes.length >= 5 &&
      String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
  return isPdf ? 'application/pdf' : image;
}

/// Device-local [DentalRecordRepository] for demo mode and tests. Records
/// persist in SharedPreferences; attachment bytes stay in memory for the
/// current app run only, like screening photos.
class LocalDentalRecordRepository implements DentalRecordRepository {
  static String _key(String userId) => 'dental.records.v1.$userId';

  /// Attachment bytes by attachment id, for this app run.
  static final Map<String, Uint8List> _bytes = {};

  @override
  Future<List<DentalRecord>> fetchAll(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return const [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => _withBytes(DentalRecord.fromJson(e as Map<String, dynamic>)))
        .toList()
      ..sort(compareRecords);
  }

  @override
  Future<DentalRecord> fetch(String userId, String id) async {
    final record = (await fetchAll(userId)).where((r) => r.id == id).firstOrNull;
    if (record == null) throw _notFound;
    return record;
  }

  @override
  Future<DentalRecord> create(String userId, DentalRecordInput input) async {
    final now = DateTime.now();
    final record = _fromInput(
      '${now.microsecondsSinceEpoch}',
      input,
      createdAt: now,
      updatedAt: now,
    );
    await _write(userId, [record, ...await fetchAll(userId)]);
    return record;
  }

  @override
  Future<DentalRecord> update(
    String userId,
    String id,
    DentalRecordInput input,
  ) async {
    final current = await fetch(userId, id);
    final record = _fromInput(
      id,
      input,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      attachments: current.attachments,
    );
    await _replace(userId, record);
    return record;
  }

  @override
  Future<void> delete(String userId, String id) async {
    final all = await fetchAll(userId);
    for (final a in all.where((r) => r.id == id).expand((r) => r.attachments)) {
      _bytes.remove(a.id);
    }
    await _write(userId, all.where((r) => r.id != id).toList());
  }

  @override
  Future<DentalRecord> addAttachment(
    String userId,
    String id,
    Uint8List bytes, {
    String? fileName,
  }) async {
    final current = await fetch(userId, id);
    final type = fileContentType(bytes);
    if (type == 'application/octet-stream') {
      throw const ApiException(
          415, 'unsupported_file', 'Use a JPEG, PNG or WebP photo, or a PDF.');
    }
    final attachment = RecordAttachment(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      kind: type == 'application/pdf' ? 'document' : 'image',
      contentType: type,
      fileName: fileName,
      sizeBytes: bytes.length,
      uploadedAt: DateTime.now(),
      bytes: bytes,
    );
    _bytes[attachment.id] = bytes;
    final record =
        current.copyWith(attachments: [...current.attachments, attachment]);
    await _replace(userId, record);
    return record;
  }

  @override
  Future<DentalRecord> removeAttachment(
    String userId,
    String id,
    String attachmentId,
  ) async {
    final current = await fetch(userId, id);
    _bytes.remove(attachmentId);
    final record = current.copyWith(
      attachments:
          current.attachments.where((a) => a.id != attachmentId).toList(),
    );
    await _replace(userId, record);
    return record;
  }

  /// Removes everything stored on this device for [userId], e.g. after
  /// the account is deleted.
  static Future<void> deleteAllFor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
    _bytes.clear();
  }

  static const _notFound = ApiException(
      404, 'not_found', 'That record is no longer in your history.');

  DentalRecord _fromInput(
    String id,
    DentalRecordInput input, {
    required DateTime createdAt,
    required DateTime updatedAt,
    List<RecordAttachment> attachments = const [],
  }) {
    // Round-trips through the request body, so only the source's own
    // fields are kept, as on the server.
    final json = input.toJson();
    return DentalRecord.fromJson({
      ...json,
      'id': id,
      'date_unknown': json['date_unknown'] ?? false,
      'attachments': const [],
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    }).copyWith(attachments: attachments);
  }

  DentalRecord _withBytes(DentalRecord r) => r.copyWith(attachments: [
        for (final a in r.attachments)
          RecordAttachment(
            id: a.id,
            kind: a.kind,
            contentType: a.contentType,
            fileName: a.fileName,
            sizeBytes: a.sizeBytes,
            uploadedAt: a.uploadedAt,
            bytes: _bytes[a.id],
          ),
      ]);

  Future<void> _replace(String userId, DentalRecord record) async {
    final all = await fetchAll(userId);
    await _write(userId, [record, ...all.where((r) => r.id != record.id)]);
  }

  Future<void> _write(String userId, List<DentalRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = [...records]..sort(compareRecords);
    final ok = await prefs.setString(
      _key(userId),
      jsonEncode(sorted.map((r) => r.toJson()).toList()),
    );
    if (!ok) throw StateError('Dental records could not be saved.');
  }
}
