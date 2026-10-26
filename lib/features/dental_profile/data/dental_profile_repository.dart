import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/dental_answers.dart';

/// A failed dental profile operation, with a message safe to show users.
class DentalProfileException implements Exception {
  const DentalProfileException(
    this.message, {
    this.sessionEnded = false,
    this.offline = false,
  });

  final String message;

  /// The user has to sign in again.
  final bool sessionEnded;

  /// DENTRA couldn't be reached; trying again later may work.
  final bool offline;

  @override
  String toString() => 'DentalProfileException($message)';
}

/// Data access for the signed-in user's dental profile.
///
/// `ApiDentalProfileRepository` backs it when the DENTRA backend is
/// configured, and the database is then the only source of truth.
/// [LocalDentalProfileRepository] is the offline demo store used when no
/// backend is set, like every other feature's on-device fallback.
abstract class DentalProfileRepository {
  /// Whether the stored profile exists, i.e. onboarding was completed.
  Future<bool> fetchOnboardingCompleted(String userId);

  /// The stored profile, or null before onboarding.
  Future<DentalProfile?> fetchProfile(String userId);

  /// Saves the complete questionnaire (creates or replaces the profile).
  /// Throws [DentalProfileException]; nothing counts as saved until this
  /// returns.
  Future<DentalProfile> submitProfile(String userId, DentalAnswers answers);

  /// Changes the answers of an existing profile.
  Future<DentalProfile> updateProfile(String userId, DentalAnswers answers);
}

/// Device-local [DentalProfileRepository] for demo mode (no backend).
class LocalDentalProfileRepository implements DentalProfileRepository {
  LocalDentalProfileRepository({
    this.latency = const Duration(milliseconds: 700),
  });

  /// Simulated round-trip time. Tests pass [Duration.zero].
  final Duration latency;

  static String _key(String userId) => 'dental_profile.v1.$userId';

  @override
  Future<bool> fetchOnboardingCompleted(String userId) async =>
      await fetchProfile(userId) != null;

  @override
  Future<DentalProfile?> fetchProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;
    return DentalProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<DentalProfile> submitProfile(String userId, DentalAnswers answers) =>
      _save(userId, answers);

  @override
  Future<DentalProfile> updateProfile(String userId, DentalAnswers answers) =>
      _save(userId, answers);

  Future<DentalProfile> _save(String userId, DentalAnswers answers) async {
    await Future<void>.delayed(latency);
    final current = await fetchProfile(userId);
    final normalized = answers.normalized();
    if (current != null && current.answers == normalized) return current;
    final now = DateTime.now();
    final profile = DentalProfile(
      answers: normalized,
      version: (current?.version ?? 0) + 1,
      completedAt: current?.completedAt ?? now,
      updatedAt: now,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(profile.toJson()));
    return profile;
  }
}
