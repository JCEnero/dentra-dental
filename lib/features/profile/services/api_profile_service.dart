import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../data/models/user_profile.dart';
import 'profile_service.dart';

/// [ProfileService] backed by the DENTRA API (`/api/users/me`).
///
/// The server takes the user from the access token, so [userId] arguments
/// are only kept for the interface: nobody can touch another account.
class ApiProfileService implements ProfileService {
  ApiProfileService(this._api);

  final ApiClient _api;

  static const _connectionError =
      "We couldn't reach Dentra. Check your connection and try again.";

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    final body = await _api.send('GET', '/api/users/me');
    return _profileFrom(body['user'] as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> updateProfile(String userId, UserProfile profile) async {
    final Map<String, dynamic> body;
    try {
      body = await _api.send('PATCH', '/api/users/me', json: profile.toJson());
    } on ApiException catch (e) {
      throw _toProfileException(e);
    } catch (_) {
      throw const ProfileException(_connectionError);
    }
    // The photo isn't part of this call; keep the one already loaded.
    return UserProfile.fromJson(
      body['user'] as Map<String, dynamic>,
      avatarBytes: profile.avatarBytes,
    );
  }

  @override
  Future<void> updateAvatar(String userId, Uint8List? bytes) async {
    try {
      if (bytes == null) {
        await _api.send('DELETE', '/api/users/me/avatar');
      } else {
        await _api.send(
          'PUT',
          '/api/users/me/avatar',
          bytes: bytes,
          contentType: imageContentType(bytes),
        );
      }
    } on ApiException catch (e) {
      throw ProfileException(e.message);
    } catch (_) {
      throw const ProfileException(_connectionError);
    }
  }

  /// Nothing to clean up on the device: deleting the account on the
  /// server (AuthService.deleteAccount) removes the profile with it.
  @override
  Future<void> deleteProfile(String userId) async {}

  Future<UserProfile> _profileFrom(Map<String, dynamic> json) async {
    final avatarUrl = json['avatar_url'] as String?;
    Uint8List? avatar;
    if (avatarUrl != null) {
      try {
        avatar = await _api.download(avatarUrl);
      } catch (_) {
        // A missing photo shouldn't block the profile; initials show.
      }
    }
    return UserProfile.fromJson(json, avatarBytes: avatar);
  }

  static ProfileException _toProfileException(ApiException e) {
    const fieldsByKey = {
      'full_name': ProfileField.fullName,
      'email': ProfileField.email,
      'phone': ProfileField.phone,
      'date_of_birth': ProfileField.dateOfBirth,
    };
    for (final entry in e.fields.entries) {
      final field = fieldsByKey[entry.key];
      if (field != null) return ProfileException(entry.value, field: field);
    }
    return ProfileException(e.message);
  }
}
