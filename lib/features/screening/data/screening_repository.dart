import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/screening_session.dart';

/// Data access for screening history.
///
/// Screens and providers only use this interface. `ApiScreeningRepository`
/// backs it when the DENTRA backend is configured, [LocalScreeningRepository]
/// otherwise (demo mode and tests); see `screeningRepositoryProvider`.
abstract class ScreeningRepository {
  /// All sessions for [userId], newest first.
  Future<List<ScreeningSession>> fetchSessions(String userId);

  /// Inserts or replaces by id, so retries never create duplicates.
  Future<ScreeningSession> upsertSession(
      String userId, ScreeningSession session);

  Future<void> deleteSession(String userId, String sessionId);

  Future<void> deleteAll(String userId);

  /// Stores the photo (or, with [modality] 'nir', the device's paired NIR
  /// frame) for one captured region and returns the updated session, or
  /// null where images aren't persisted (on-device store).
  Future<ScreeningSession?> uploadCaptureImage(
    String userId,
    String sessionId,
    String regionId,
    Uint8List bytes, {
    String modality = 'rgb',
  });

  /// Saves what the user said about the tooth behind [findingId], or takes the
  /// answer back when [pain] is null, and returns the updated session. The
  /// answer is kept apart from the finding and never changes it.
  Future<ScreeningSession> answerFinding(
    String userId,
    String sessionId,
    String findingId,
    ToothPain? pain,
  );
}

/// Device-local [ScreeningRepository] backed by SharedPreferences.
class LocalScreeningRepository implements ScreeningRepository {
  // v1 held one list for the whole device; it is kept as the store for
  // records without an owner and migrated on first read for each user.
  static const String _legacyKey = 'screening.sessions.v1';
  static String _key(String userId) => 'screening.sessions.v2.$userId';

  @override
  Future<List<ScreeningSession>> fetchSessions(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_key(userId));
    if (raw == null) {
      // First read for this user: adopt the device's unowned v1 records.
      raw = prefs.getString(_legacyKey);
      if (raw != null) {
        await prefs.setString(_key(userId), raw);
        await prefs.remove(_legacyKey);
      }
    }
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => ScreeningSession.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return list;
  }

  @override
  Future<ScreeningSession> upsertSession(
    String userId,
    ScreeningSession session,
  ) async {
    final now = DateTime.now();
    final current = await fetchSessions(userId);
    final existing = current.where((s) => s.id == session.id).firstOrNull;
    final stored = ScreeningSession(
      id: session.id,
      userId: userId,
      completedAt: session.completedAt,
      capturedRegions: session.capturedRegions,
      totalRegions: session.totalRegions,
      captures: session.captures,
      analysis: session.analysis,
      reportedContext: session.reportedContext ?? existing?.reportedContext,
      checkIn: session.checkIn ?? existing?.checkIn,
      // Answers change through answerFinding; saving the scan again keeps them.
      findingAnswers: session.findingAnswers.isEmpty
          ? existing?.findingAnswers ?? const []
          : session.findingAnswers,
      createdAt: existing?.createdAt ?? session.createdAt ?? now,
      updatedAt: now,
    );
    final next = [stored, ...current.where((s) => s.id != session.id)]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    await _write(userId, next);
    return stored;
  }

  @override
  Future<void> deleteSession(String userId, String sessionId) async {
    final current = await fetchSessions(userId);
    await _write(userId, current.where((s) => s.id != sessionId).toList());
  }

  @override
  Future<void> deleteAll(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  /// Not persisted on the device: images stay in memory for this app run
  /// (see `screeningImageCacheProvider`).
  @override
  Future<ScreeningSession?> uploadCaptureImage(
    String userId,
    String sessionId,
    String regionId,
    Uint8List bytes, {
    String modality = 'rgb',
  }) async =>
      null;

  @override
  Future<ScreeningSession> answerFinding(
    String userId,
    String sessionId,
    String findingId,
    ToothPain? pain,
  ) async {
    final current = await fetchSessions(userId);
    final session = current.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) {
      throw StateError('That screening is no longer in your history.');
    }
    final updated = session.withAnswer(findingId, pain);
    await _write(userId, [
      for (final s in current) s.id == sessionId ? updated : s,
    ]);
    return updated;
  }

  Future<void> _write(String userId, List<ScreeningSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      _key(userId),
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
    if (!ok) throw StateError('Screening history could not be saved.');
  }
}
