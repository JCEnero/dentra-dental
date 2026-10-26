import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/dental_record_repository.dart';
import '../data/models/dental_record.dart';

/// Backend for dental records: the DENTRA API when configured, the
/// on-device store otherwise. Override in tests.
final dentalRecordRepositoryProvider = Provider<DentalRecordRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return api == null
      ? LocalDentalRecordRepository()
      : ApiDentalRecordRepository(api);
});

/// The signed-in user's clinic visits, personal photos and notes, newest
/// first. Reloads when the signed-in user changes.
class DentalRecordsNotifier extends AsyncNotifier<List<DentalRecord>> {
  static const _guestId = 'guest';

  DentalRecordRepository get _repo => ref.read(dentalRecordRepositoryProvider);
  String _userId = _guestId;

  @override
  Future<List<DentalRecord>> build() async {
    _userId = ref.watch(authServiceProvider.select((a) => a.currentUserId)) ??
        _guestId;
    return _repo.fetchAll(_userId);
  }

  DentalRecord? byId(String id) =>
      state.valueOrNull?.where((r) => r.id == id).firstOrNull;

  Future<DentalRecord> create(DentalRecordInput input) async {
    final saved = await _repo.create(_userId, input);
    _replaceLocal(saved);
    return saved;
  }

  Future<DentalRecord> save(String id, DentalRecordInput input) async {
    final saved = await _repo.update(_userId, id, input);
    _replaceLocal(saved);
    return saved;
  }

  /// Re-reads one record, e.g. for fresh attachment links. Drops it from
  /// the list when the server says it's gone.
  Future<void> refreshRecord(String id) async {
    try {
      _replaceLocal(await _repo.fetch(_userId, id));
    } on ApiException catch (e) {
      if (e.statusCode == 404) _removeLocal(id);
      rethrow;
    }
  }

  /// Deletes a record. Restores it and rethrows if the delete fails.
  Future<void> delete(String id) async {
    final previous = state.valueOrNull ?? const <DentalRecord>[];
    _removeLocal(id);
    try {
      await _repo.delete(_userId, id);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<DentalRecord> addAttachment(
    String id,
    Uint8List bytes, {
    String? fileName,
  }) async {
    final saved =
        await _repo.addAttachment(_userId, id, bytes, fileName: fileName);
    _replaceLocal(saved);
    return saved;
  }

  Future<DentalRecord> removeAttachment(String id, String attachmentId) async {
    final saved = await _repo.removeAttachment(_userId, id, attachmentId);
    _replaceLocal(saved);
    return saved;
  }

  void _replaceLocal(DentalRecord record) {
    final current = state.valueOrNull ?? const <DentalRecord>[];
    state = AsyncData(
      [record, ...current.where((r) => r.id != record.id)]..sort(compareRecords),
    );
  }

  void _removeLocal(String id) {
    final current = state.valueOrNull ?? const <DentalRecord>[];
    state = AsyncData(current.where((r) => r.id != id).toList());
  }
}

final dentalRecordsProvider =
    AsyncNotifierProvider<DentalRecordsNotifier, List<DentalRecord>>(
  DentalRecordsNotifier.new,
);

/// A message for the user from a failed records call.
String dentalRecordErrorMessage(Object error, String fallback) =>
    error is ApiException ? error.message : fallback;
