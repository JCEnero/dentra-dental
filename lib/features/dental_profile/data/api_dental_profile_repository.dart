import '../../../core/network/api_client.dart';
import 'dental_profile_repository.dart';
import 'models/dental_answers.dart';

/// [DentalProfileRepository] backed by the DENTRA API
/// (`/api/dental-profile`).
///
/// The server takes the user from the access token, so [userId] arguments
/// are only kept for the interface: nobody can touch another user's
/// profile.
class ApiDentalProfileRepository implements DentalProfileRepository {
  ApiDentalProfileRepository(this._api);

  final ApiClient _api;

  static const _path = '/api/dental-profile';
  static const _connectionError =
      "We couldn't reach Dentra. Check your connection and try again.";

  @override
  Future<bool> fetchOnboardingCompleted(String userId) async {
    final body = await _call('GET', '$_path/onboarding-status');
    return body['onboarding_completed'] == true;
  }

  @override
  Future<DentalProfile?> fetchProfile(String userId) async {
    final body = await _call('GET', _path);
    final profile = body['profile'];
    return profile == null
        ? null
        : DentalProfile.fromJson(profile as Map<String, dynamic>);
  }

  @override
  Future<DentalProfile> submitProfile(
    String userId,
    DentalAnswers answers,
  ) async {
    final body = await _call('POST', _path, json: answers.toJson());
    return _confirmed(body);
  }

  @override
  Future<DentalProfile> updateProfile(
    String userId,
    DentalAnswers answers,
  ) async {
    final body = await _call('PATCH', _path, json: answers.toJson());
    return _confirmed(body);
  }

  /// Only a response that carries the stored profile counts as saved.
  DentalProfile _confirmed(Map<String, dynamic> body) {
    final profile = body['profile'];
    if (body['onboarding_completed'] != true || profile is! Map) {
      throw const DentalProfileException(
        "We couldn't confirm your answers were saved. Please try again.",
      );
    }
    return DentalProfile.fromJson(profile.cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, dynamic>? json,
  }) async {
    try {
      return await _api.send(method, path, json: json);
    } on ApiException catch (e) {
      throw DentalProfileException(
        e.message,
        sessionEnded: e.isUnauthenticated,
      );
    } catch (_) {
      // Offline, timed out, or an unreadable response.
      throw const DentalProfileException(_connectionError, offline: true);
    }
  }
}
