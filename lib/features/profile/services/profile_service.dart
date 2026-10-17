import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/user_profile.dart';

/// Profile fields a save can reject, so the form can point at the input.
enum ProfileField { fullName, email, phone, dateOfBirth }

/// A failed profile operation, with a message that is safe to show users.
class ProfileException implements Exception {
  final String message;

  /// The field the error belongs to, or null for a general failure.
  final ProfileField? field;

  const ProfileException(this.message, {this.field});

  @override
  String toString() => 'ProfileException($message)';
}

/// Data access for user profiles.
///
/// The UI only talks to this interface. Today [LocalProfileService] backs
/// it; when the PostgreSQL backend is ready, add an API-backed
/// implementation (the app should call your REST/Supabase API, never the
/// database directly) and swap it in `profileServiceProvider`.
///
/// Expected table (see `UserProfile.toJson` for the column names):
///   users(id uuid pk, full_name text, email text unique, phone text,
///         date_of_birth date, gender text, avatar_url text,
///         analytics_consent bool, marketing_consent bool,
///         two_factor_enabled bool, created_at timestamptz,
///         updated_at timestamptz)
abstract class ProfileService {
  /// Loads the stored profile, or null if this user has none yet.
  Future<UserProfile?> fetchProfile(String userId);

  /// Saves profile details and preferences (not the photo) and returns
  /// the stored result. Throws [ProfileException] on failure.
  Future<UserProfile> updateProfile(String userId, UserProfile profile);

  /// Replaces the profile photo, or removes it when [bytes] is null.
  Future<void> updateAvatar(String userId, Uint8List? bytes);

  /// Removes everything stored for this user. Used by account deletion.
  Future<void> deleteProfile(String userId);
}

/// Device-local [ProfileService]: simulates network latency and keeps the
/// profile in SharedPreferences, keyed by user id.
class LocalProfileService implements ProfileService {
  LocalProfileService({
    this.latency = const Duration(milliseconds: 900),
  });

  /// Simulated round-trip time. Tests pass [Duration.zero].
  final Duration latency;

  static String _profileKey(String userId) => 'profile.v1.$userId';
  static String _avatarKey(String userId) => 'profile.avatar.v1.$userId';

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    // API equivalent: GET /users/{id}
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey(userId));
    if (raw == null) return null;
    final avatar = prefs.getString(_avatarKey(userId));
    return UserProfile.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
      avatarBytes: avatar == null ? null : base64Decode(avatar),
    );
  }

  @override
  Future<UserProfile> updateProfile(String userId, UserProfile profile) async {
    // API equivalent: PATCH /users/{id} with profile.toJson().
    // Map 409 (email taken) / 422 (invalid field) to ProfileException with
    // a field. A real backend should also re-verify a changed email.
    await Future.delayed(latency);

    // Simulates an email owned by another account, matching the
    // duplicate-email demo in AuthService.registerWithEmail.
    if (profile.email.toLowerCase() == 'taken@dentra.com') {
      throw const ProfileException(
        'This email is already linked to another account.',
        field: ProfileField.email,
      );
    }

    final stored = profile.copyWith(updatedAt: DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _profileKey(userId),
      jsonEncode(stored.toJson()),
    );
    if (!saved) {
      throw const ProfileException(
        "We couldn't save your changes. Please try again.",
      );
    }
    return stored;
  }

  @override
  Future<void> updateAvatar(String userId, Uint8List? bytes) async {
    // API equivalent: multipart POST /users/{id}/avatar (store the file in
    // object storage, keep only avatar_url in Postgres), or DELETE.
    await Future.delayed(latency);
    final prefs = await SharedPreferences.getInstance();
    final ok = bytes == null
        ? await prefs.remove(_avatarKey(userId))
        : await prefs.setString(_avatarKey(userId), base64Encode(bytes));
    if (!ok) {
      throw const ProfileException(
        "We couldn't update your photo. Please try again.",
      );
    }
  }

  @override
  Future<void> deleteProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey(userId));
    await prefs.remove(_avatarKey(userId));
  }
}
