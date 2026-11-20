import 'dart:math';

import '../data/saved_camera.dart';
import 'cloud_cam_api.dart';
import 'dentra_cam_client.dart';
import 'wifi_provisioning.dart';

/// Links a locally provisioned camera to the signed-in account, then verifies
/// its live relay status after the phone leaves the temporary setup network.
class AccountWifiProvisioning extends ProvisioningTransport {
  AccountWifiProvisioning({
    required ProvisioningTransport transport,
    required CloudCamApi api,
    required CamClient Function(String) clientFor,
  })  : _transport = transport,
        _api = api,
        _clientFor = clientFor;

  final ProvisioningTransport _transport;
  final CloudCamApi _api;
  final CamClient Function(String) _clientFor;
  final String _session = List.generate(12, (_) => Random.secure().nextInt(256))
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  CamPairing? _pairing;
  String? _hardwareId;
  CloudCamera? _linked;
  CamClient? _client;
  bool _closed = false;
  bool _verified = false;

  @override
  bool get usesBrowserWifi => _transport.usesBrowserWifi;
  @override
  bool get linksAccount => true;

  @override
  Future<void> prepare() async {
    await _transport.prepare();
    if (_closed) return;
    if (_pairing != null && _pairing!.expiresAt.isAfter(DateTime.now())) return;
    try {
      final pairing = await _api.createPairing();
      if (!_closed) _pairing = pairing;
    } catch (_) {
      throw const ProvisioningException(
          'Stay on your home Wi-Fi or mobile data while we start setup. Check your internet connection and try again.');
    }
  }

  @override
  Future<void> joinHotspot(String setupKey) => _transport.joinHotspot(setupKey);

  @override
  Future<Map<String, dynamic>> get(String path) async {
    final response = await _transport.get(path);
    if (_closed) throw StateError('Setup closed');
    if (path == '/setup/info') {
      if (response['protocol'] != 2 ||
          response['protected'] != true ||
          response['session_setup'] != true) {
        throw const ProvisioningException(
            'Update your Dentra Cam to firmware 2.0.0 or later to use in-app Wi-Fi setup.');
      }
      _hardwareId = response['id'] as String?;
    }
    return response;
  }

  @override
  Future<Map<String, dynamic>> post(
      String path, Map<String, String> body) async {
    if (_closed) throw StateError('Setup closed');
    if (path == '/setup/join') {
      final pairing = _pairing;
      if (pairing == null || !pairing.expiresAt.isAfter(DateTime.now())) {
        throw const ProvisioningException(
            'This setup session expired. Return to home Wi-Fi, close setup, and start again.');
      }
      return _transport
          .post(path, {...body, 'code': pairing.code, 'session': _session});
    }
    return _transport.post(path, body);
  }

  @override
  Future<void> leaveHotspot() => _transport.leaveHotspot();
  @override
  Future<String?> discover(String deviceId) async => null;

  @override
  Future<Map<String, dynamic>> cameraStatus(String host) async {
    final pairing = _pairing;
    if (_closed || pairing == null) throw StateError('No setup session');
    final status = await _api.pairing(pairing.id);
    if (_closed) throw StateError('Setup closed');
    if (status.state == PairingState.expired) {
      throw const ProvisioningException(
          'Your device joined Wi-Fi, but account linking expired. Start setup again to link it.');
    }
    final camera = status.camera;
    if (status.state != PairingState.claimed ||
        camera == null ||
        !camera.online) {
      throw const FormatException('Camera is not linked and online yet');
    }
    if (camera.hardwareId?.toUpperCase() != _hardwareId?.toUpperCase()) {
      throw const ProvisioningException(
          'The linked camera doesn’t match this device. Close setup and try again.');
    }
    _verified = false;
    _linked = camera;
    _client ??= _clientFor(camera.id);
    final live = await _client!.status(timeout: const Duration(seconds: 12));
    if (_closed) throw StateError('Setup closed');
    _verified = live.deviceId == _hardwareId &&
        live.cameraReady == true &&
        live.setupSession == _session;
    return {'id': live.deviceId, 'camera_ok': _verified};
  }

  @override
  Future<SavedCamera> finalizeCamera(
      {required String name, String? host, String? ssid}) async {
    final linked = _linked;
    if (_closed || !_verified || linked == null) {
      throw StateError('Camera not verified');
    }
    return linked.toSaved();
  }

  @override
  void close() {
    _closed = true;
    _client?.close();
    _transport.close();
    _pairing = null;
  }
}
