import 'dart:typed_data';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/dental_records/data/dental_record_repository.dart';
import 'package:dentra_mobile/features/dental_records/data/models/dental_record.dart';
import 'package:dentra_mobile/features/screening/data/models/screening_session.dart';
import 'package:dentra_mobile/features/screening/data/screening_repository.dart';

/// A valid 1×1 PNG, so image widgets decode something real.
final Uint8List tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Screening history held in memory.
class FakeScreeningRepository implements ScreeningRepository {
  FakeScreeningRepository([List<ScreeningSession> sessions = const []])
      : sessions = [...sessions];

  final List<ScreeningSession> sessions;

  @override
  Future<List<ScreeningSession>> fetchSessions(String userId) async =>
      [...sessions]..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  @override
  Future<ScreeningSession> upsertSession(String userId, ScreeningSession s) async {
    sessions
      ..removeWhere((x) => x.id == s.id)
      ..add(s);
    return s;
  }

  @override
  Future<void> deleteSession(String userId, String sessionId) async =>
      sessions.removeWhere((s) => s.id == sessionId);

  @override
  Future<void> deleteAll(String userId) async => sessions.clear();

  @override
  Future<ScreeningSession?> uploadCaptureImage(
          String userId, String sessionId, String regionId, Uint8List bytes,
          {String modality = 'rgb'}) async =>
      null;

  /// Every answer saved, in order: (session, finding, answer).
  final List<(String, String, ToothPain?)> answers = [];

  /// Thrown by the next answerFinding while set.
  Object? answerError;

  @override
  Future<ScreeningSession> answerFinding(String userId, String sessionId,
      String findingId, ToothPain? pain) async {
    if (answerError case final error?) throw error;
    answers.add((sessionId, findingId, pain));
    final i = sessions.indexWhere((s) => s.id == sessionId);
    if (i < 0) throw const ApiException(404, 'not_found', 'Gone.');
    return sessions[i] = sessions[i].withAnswer(findingId, pain);
  }
}

/// Dental records held in memory, with predictable ids.
class FakeDentalRecordRepository implements DentalRecordRepository {
  FakeDentalRecordRepository([List<DentalRecord> records = const []])
      : records = [...records];

  final List<DentalRecord> records;
  final List<DentalRecordInput> created = [];

  /// Thrown by the next fetchAll while set.
  Object? fetchError;
  var _next = 1;

  @override
  Future<List<DentalRecord>> fetchAll(String userId) async {
    if (fetchError != null) throw fetchError!;
    return [...records]..sort(compareRecords);
  }

  @override
  Future<DentalRecord> fetch(String userId, String id) async =>
      records.firstWhere((r) => r.id == id,
          orElse: () => throw const ApiException(404, 'not_found', 'Gone.'));

  @override
  Future<DentalRecord> create(String userId, DentalRecordInput input) async {
    created.add(input);
    final r = recordFrom(input, id: 'r${_next++}');
    records.add(r);
    return r;
  }

  @override
  Future<DentalRecord> update(String userId, String id, DentalRecordInput input) async {
    final current = await fetch(userId, id);
    final r = recordFrom(input, id: id).copyWith(attachments: current.attachments);
    records[records.indexOf(current)] = r;
    return r;
  }

  @override
  Future<void> delete(String userId, String id) async =>
      records.removeWhere((r) => r.id == id);

  @override
  Future<DentalRecord> addAttachment(String userId, String id, Uint8List bytes,
      {String? fileName}) async {
    final current = await fetch(userId, id);
    final r = current.copyWith(attachments: [
      ...current.attachments,
      imageAttachment('a${_next++}'),
    ]);
    records[records.indexOf(current)] = r;
    return r;
  }

  @override
  Future<DentalRecord> removeAttachment(String userId, String id, String attachmentId) async {
    final current = await fetch(userId, id);
    final r = current.copyWith(
        attachments: current.attachments.where((a) => a.id != attachmentId).toList());
    records[records.indexOf(current)] = r;
    return r;
  }
}

RecordAttachment imageAttachment(String id) => RecordAttachment(
      id: id,
      kind: 'image',
      contentType: 'image/png',
      sizeBytes: tinyPng.length,
      uploadedAt: DateTime(2026, 10, 1),
      bytes: tinyPng,
    );

DentalRecord recordFrom(DentalRecordInput input, {required String id}) {
  final json = input.toJson();
  return DentalRecord.fromJson({
    ...json,
    'id': id,
    'date_unknown': json['date_unknown'] ?? false,
    'attachments': const [],
    'created_at': DateTime(2026, 10, 1, 9).toUtc().toIso8601String(),
    'updated_at': DateTime(2026, 10, 1, 9).toUtc().toIso8601String(),
  });
}

/// A personal photo record with one image.
DentalRecord photoRecord(String id, DateTime day, {List<String> teeth = const []}) =>
    recordFrom(
      DentalRecordInput(
        source: RecordSource.personalPhoto,
        recordDate: day,
        toothNumbers: teeth,
        notes: 'Front teeth',
      ),
      id: id,
    ).copyWith(attachments: [imageAttachment('img-$id')]);

ScreeningSession screening(
  String id,
  DateTime at, {
  List<String> regions = const ['ul', 'ur'],
  List<ScreeningFinding>? findings,
}) =>
    ScreeningSession(
      id: id,
      completedAt: at,
      capturedRegions: regions,
      totalRegions: 5,
      analysis: findings == null
          ? null
          : ScreeningAnalysis(
              summary: 'Test summary',
              analyzedAt: at,
              findings: findings,
            ),
    );
