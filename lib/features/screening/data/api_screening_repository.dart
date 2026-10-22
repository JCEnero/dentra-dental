import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import 'models/screening_session.dart';
import 'screening_repository.dart';

/// [ScreeningRepository] backed by the DENTRA API (`/api/screenings`).
///
/// The server scopes every call to the token's user, so [userId]
/// arguments are only kept for the interface.
class ApiScreeningRepository implements ScreeningRepository {
  ApiScreeningRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ScreeningSession>> fetchSessions(String userId) async {
    final body = await _api.send('GET', '/api/screenings');
    return [
      for (final item in body['items'] as List<dynamic>)
        _sessionFrom(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<ScreeningSession> upsertSession(
    String userId,
    ScreeningSession session,
  ) async {
    final body = await _api.send(
      'PUT',
      '/api/screenings/${Uri.encodeComponent(session.id)}',
      json: session.toJson(),
    );
    return _sessionFrom(body['session'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteSession(String userId, String sessionId) =>
      _api.send('DELETE', '/api/screenings/${Uri.encodeComponent(sessionId)}');

  @override
  Future<void> deleteAll(String userId) =>
      _api.send('DELETE', '/api/screenings');

  @override
  Future<ScreeningSession?> uploadCaptureImage(
    String userId,
    String sessionId,
    String regionId,
    Uint8List bytes, {
    String modality = 'rgb',
  }) async {
    final body = await _api.send(
      'PUT',
      '/api/screenings/${Uri.encodeComponent(sessionId)}/captures/$regionId/image',
      query: modality == 'rgb' ? null : {'modality': modality},
      bytes: bytes,
      contentType: imageContentType(bytes),
    );
    return screeningSessionFromApi(_api, body['session'] as Map<String, dynamic>);
  }

  ScreeningSession _sessionFrom(Map<String, dynamic> json) =>
      screeningSessionFromApi(_api, json);
}

/// Parses a session from the API. Image URLs come back relative to the
/// API in development storage.
ScreeningSession screeningSessionFromApi(
  ApiClient api,
  Map<String, dynamic> json,
) {
  final captures = json['captures'] as List<dynamic>? ?? const [];
  for (final c in captures.cast<Map<String, dynamic>>()) {
    for (final key in const ['image_url', 'nir_image_url']) {
      final url = c[key] as String?;
      if (url != null) c[key] = api.resolve(url);
    }
  }
  return ScreeningSession.fromJson(json);
}
