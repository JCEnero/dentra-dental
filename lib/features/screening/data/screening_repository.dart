import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/screening_session.dart';

/// Data access for screening history.
///
/// Screens and providers only use this interface. [LocalScreeningRepository]
/// backs it today; when the PostgreSQL backend is ready, add an API-backed
/// implementation (the app calls your REST/Supabase API, never the
/// database directly) and swap it in `screeningRepositoryProvider`.
///
/// Suggested endpoints (tables in `database/schema.sql`):
///   GET    /users/{userId}/screenings?order=completed_at.desc
///   PUT    /screenings/{id}        (upsert, idempotent on id)
///   DELETE /screenings/{id}
///   DELETE /users/{userId}/screenings
abstract class ScreeningRepository {
  /// All sessions for [userId], newest first.
  Future<List<ScreeningSession>> fetchSessions(String userId);

  /// Inserts or replaces by id, so retries never create duplicates.
  Future<ScreeningSession> upsertSession(String userId, ScreeningSession session);

  Future<void> deleteSession(String userId, String sessionId);

  Future<void> deleteAll(String userId);
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

  Future<void> _write(String userId, List<ScreeningSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      _key(userId),
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
    if (!ok) throw StateError('Screening history could not be saved.');
  }
}
