import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/screening_session.dart';

/// The user's recorded screening sessions, newest first, persisted with
/// SharedPreferences.
class ScreeningSessionsNotifier extends AsyncNotifier<List<ScreeningSession>> {
  // Bump the suffix if the stored shape changes incompatibly.
  static const String _storageKey = 'screening.sessions.v1';

  @override
  Future<List<ScreeningSession>> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => ScreeningSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Unreadable history should not block scanning.
      return const [];
    }
  }

  /// Adds [session] to the history. The in-memory list updates even if
  /// persisting fails; the error is rethrown so the caller can tell the user.
  Future<void> record(ScreeningSession session) async {
    final current = await future;
    final next = [session, ...current];
    state = AsyncData(next);

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _storageKey,
      jsonEncode(next.map((s) => s.toJson()).toList()),
    );
    if (!saved) throw StateError('Screening history could not be saved.');
  }
}

final screeningSessionsProvider =
    AsyncNotifierProvider<ScreeningSessionsNotifier, List<ScreeningSession>>(
  ScreeningSessionsNotifier.new,
);
