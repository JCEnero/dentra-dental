import 'dart:async';

import 'package:dentra_mobile/features/camera/services/wifi_provisioning.dart';
import 'package:dentra_mobile/features/camera/data/saved_camera.dart';

class FakeProvisioning extends ProvisioningTransport {
  bool browser = false;
  bool account = false;
  bool loseStatusAfterJoin = false;
  @override
  bool get linksAccount => account || browser;
  @override
  bool get usesBrowserWifi => browser;

  @override
  Future<SavedCamera> finalizeCamera(
          {required String name, String? host, String? ssid}) async =>
      (browser || account)
          ? SavedCamera(cloudId: 'cam-1', name: name, savedAt: DateTime.now())
          : SavedCamera(
              host: host, name: name, ssid: ssid, savedAt: DateTime.now());
  static const id = 'AABBCCDD3F2A';
  static const token = '0123456789abcdef0123456789abcdef';
  final calls = <String>[];
  final posts = <(String, Map<String, String>)>[];
  String state = 'idle';
  String? failure;
  String cameraId = id;
  bool cameraReady = true;
  bool cameraReachable = true;
  bool loseJoinReply = false;
  bool loseFinishReply = false;
  bool closed = false;
  String ip = '192.168.1.40';
  String? discovered;
  Object? joinError;
  Object? leaveError;
  Completer<void>? joinGate;
  Completer<void>? statusGate;
  bool protected = true;
  String homeSsid = 'Home';

  @override
  Future<void> joinHotspot(String setupKey) async {
    calls.add('join');
    if (joinError != null) throw joinError!;
    await joinGate?.future;
  }

  @override
  Future<void> leaveHotspot() async {
    calls.add('leave');
    if (leaveError != null) throw leaveError!;
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    calls.add(path);
    if (path == '/setup/status' &&
        state == 'connected' &&
        loseStatusAfterJoin) {
      throw TimeoutException('DHCP response lost during radio handoff');
    }
    return switch (path) {
      '/setup/info' => {
          'id': id,
          'name': 'Dentra Cam 3F2A',
          'protocol': 2,
          'session_setup': true,
          'protected': protected,
          'token': token
        },
      '/setup/status' => {
          'id': id,
          'state': state,
          'ssid': homeSsid,
          'ip': ip,
          'error': failure
        },
      '/setup/networks' => {
          'networks': [
            {'ssid': 'Cafe', 'rssi': -80, 'secure': false},
            {'ssid': 'Home', 'rssi': -45, 'secure': true},
            {'ssid': 'Home', 'rssi': -70, 'secure': true},
            {'ssid': '', 'rssi': -30, 'secure': true},
          ]
        },
      _ => throw StateError('Unknown path'),
    };
  }

  @override
  Future<Map<String, dynamic>> post(
      String path, Map<String, String> body) async {
    calls.add(path);
    posts.add((path, {...body}));
    if (path == '/setup/join') {
      homeSsid = body['ssid']!;
      state = failure == null ? 'connected' : 'failed';
      if (loseJoinReply) throw TimeoutException('Lost reply');
    }
    if (path == '/setup/finish' && loseFinishReply) {
      throw TimeoutException('Lost reply');
    }
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> cameraStatus(String host) async {
    calls.add('status $host');
    await statusGate?.future;
    if (!cameraReachable || (discovered != null && host != discovered)) {
      throw TimeoutException('No route');
    }
    return {'id': cameraId, 'camera_ok': cameraReady};
  }

  @override
  Future<String?> discover(String deviceId) async {
    calls.add('discover $deviceId');
    return discovered;
  }

  @override
  void close() {
    closed = true;
  }
}
