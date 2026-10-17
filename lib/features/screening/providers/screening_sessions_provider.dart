import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/screening_session.dart';
import '../data/screening_repository.dart';

/// Backend for screening history. Swap for the API-backed implementation
/// once the backend is live; override in tests.
final screeningRepositoryProvider =
    Provider<ScreeningRepository>((ref) => LocalScreeningRepository());

/// The signed-in user's screening sessions, newest first. Reloads when
/// the signed-in user changes.
class ScreeningSessionsNotifier extends AsyncNotifier<List<ScreeningSession>> {
  // Used when the app is opened without a session (e.g. during development).
  static const _guestId = 'guest';

  ScreeningRepository get _repo => ref.read(screeningRepositoryProvider);
  String _userId = _guestId;

  @override
  Future<List<ScreeningSession>> build() async {
    _userId = ref.watch(authServiceProvider.select((a) => a.currentUserId)) ??
        _guestId;
    // Errors surface as AsyncError so the history page can offer a retry.
    return _repo.fetchSessions(_userId);
  }

  /// Adds [session] to the history. The in-memory list updates even if
  /// persisting fails; the error is rethrown so the caller can tell the user.
  Future<void> record(ScreeningSession session) async {
    // Let the initial load finish first, so the new record is merged into
    // the full list rather than replacing it. A failed load still allows
    // saving: the repository upserts this one record.
    try {
      await future;
    } catch (_) {}
    _replaceLocal(session);
    final saved = await _repo.upsertSession(_userId, session);
    _replaceLocal(saved);
  }

  /// Saves changes to an existing session, e.g. analysis that arrived
  /// after the scan finished.
  Future<void> save(ScreeningSession session) => record(session);

  /// Deletes one session. Restores it and rethrows if the delete fails.
  Future<void> delete(String sessionId) async {
    final previous = state.valueOrNull ?? const <ScreeningSession>[];
    state = AsyncData(previous.where((s) => s.id != sessionId).toList());
    try {
      await _repo.deleteSession(_userId, sessionId);
      ref.read(screeningImageCacheProvider.notifier).remove(sessionId);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Removes all recorded sessions, e.g. when the account is deleted.
  Future<void> clear() async {
    state = const AsyncData([]);
    ref.read(screeningImageCacheProvider.notifier).clear();
    await _repo.deleteAll(_userId);
  }

  /// Upserts by id, keeping newest-first order and no duplicates.
  void _replaceLocal(ScreeningSession session) {
    final current = state.valueOrNull ?? const <ScreeningSession>[];
    final next = [session, ...current.where((s) => s.id != session.id)]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    state = AsyncData(next);
  }
}

final screeningSessionsProvider =
    AsyncNotifierProvider<ScreeningSessionsNotifier, List<ScreeningSession>>(
  ScreeningSessionsNotifier.new,
);

/// Captured image bytes by session id, then region id, for this app run.
///
/// Images are not persisted yet: they should be uploaded to object
/// storage by the backend (see `ScreeningCapture.imageUrl`). Until then
/// this lets the detail page show photos from scans made since launch.
class ScreeningImageCache extends Notifier<Map<String, Map<String, Uint8List>>> {
  @override
  Map<String, Map<String, Uint8List>> build() => const {};

  void put(String sessionId, Map<String, Uint8List> images) =>
      state = {...state, sessionId: Map.unmodifiable(images)};

  void remove(String sessionId) =>
      state = {...state}..remove(sessionId);

  void clear() => state = const {};
}

final screeningImageCacheProvider = NotifierProvider<ScreeningImageCache,
    Map<String, Map<String, Uint8List>>>(ScreeningImageCache.new);
