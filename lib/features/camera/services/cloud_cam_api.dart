import '../../../core/network/api_client.dart';
import '../data/saved_camera.dart';

/// A Dentra Cam linked to the signed-in account (the website's cameras).
class CloudCamera {
  const CloudCamera({
    required this.id,
    required this.name,
    required this.online,
    this.lastSeenAt,
  });

  final String id;

  /// As it calls itself, e.g. "Dentra Cam 3F2A".
  final String name;

  /// Connected to the API right now.
  final bool online;
  final DateTime? lastSeenAt;

  static CloudCamera? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    final seen = json['last_seen_at'];
    return CloudCamera(
      id: id,
      name: name,
      online: json['online'] == true,
      lastSeenAt: seen is String ? DateTime.tryParse(seen) : null,
    );
  }

  SavedCamera toSaved() => SavedCamera(
        cloudId: id,
        name: name,
        savedAt: lastSeenAt ?? DateTime.now(),
      );
}

/// A code for linking a camera, shown on the website and typed on the
/// camera's setup page.
class CamPairing {
  const CamPairing({
    required this.id,
    required this.code,
    required this.expiresAt,
  });

  final String id;

  /// Six letters and digits, e.g. "K7P2QX".
  final String code;
  final DateTime expiresAt;

  /// "K7P 2QX": easier to read out and type.
  String get displayCode => code.length == 6
      ? '${code.substring(0, 3)} ${code.substring(3)}'
      : code;
}

enum PairingState { pending, claimed, expired }

class PairingStatus {
  const PairingStatus(this.state, {this.camera});

  final PairingState state;

  /// The camera that used the code, once [PairingState.claimed].
  final CloudCamera? camera;
}

/// The DENTRA API's Dentra Cam endpoints (backend/src/modules/cam/).
class CloudCamApi {
  const CloudCamApi(this._api);

  final ApiClient _api;

  /// A fresh code; any earlier unused one stops working.
  Future<CamPairing> createPairing() async {
    final body = await _api.send('POST', '/api/cam/pairings');
    final pairing = body['pairing'];
    if (pairing is! Map ||
        pairing['id'] is! String ||
        pairing['code'] is! String) {
      throw const ApiException(500, 'bad_response', _badResponse);
    }
    return CamPairing(
      id: pairing['id'] as String,
      code: pairing['code'] as String,
      expiresAt: DateTime.tryParse('${pairing['expires_at']}') ??
          DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  Future<PairingStatus> pairing(String id) async {
    final body = await _api.send('GET', '/api/cam/pairings/$id');
    final pairing = body['pairing'];
    if (pairing is! Map) {
      throw const ApiException(500, 'bad_response', _badResponse);
    }
    final state = switch (pairing['status']) {
      'claimed' => PairingState.claimed,
      'expired' => PairingState.expired,
      _ => PairingState.pending,
    };
    return PairingStatus(state, camera: CloudCamera.fromJson(pairing['device']));
  }

  /// The account's cameras, newest first.
  Future<List<CloudCamera>> cameras() async {
    final body = await _api.send('GET', '/api/cam/devices');
    final list = body['devices'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (CloudCamera.fromJson(item) case final camera?) camera,
    ];
  }

  Future<void> forget(String id) => _api.send('DELETE', '/api/cam/devices/$id');

  static const _badResponse = 'Something went wrong. Please try again.';
}
