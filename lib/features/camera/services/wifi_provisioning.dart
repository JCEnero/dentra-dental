import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../data/camera_protocol.dart';
import '../data/saved_camera.dart';

class ProvisioningException implements Exception {
  const ProvisioningException(this.message);
  final String message;
}

/// Native joins require OS approval. Credentials travel only over the
/// device's unique WPA2-protected setup network, never an open hotspot.
abstract class ProvisioningTransport {
  bool get usesBrowserWifi => false;
  bool get linksAccount => false;
  Future<void> prepare() async {}
  Future<SavedCamera> finalizeCamera(
      {required String name, String? host, String? ssid}) async {
    if (host == null || !isIpv4(host)) {
      throw const FormatException('No local camera address');
    }
    return SavedCamera(
        host: host, name: name, ssid: ssid, savedAt: DateTime.now());
  }

  Future<void> joinHotspot(String setupKey);
  Future<void> leaveHotspot();
  Future<Map<String, dynamic>> get(String path);
  Future<Map<String, dynamic>> post(String path, Map<String, String> body);
  Future<Map<String, dynamic>> cameraStatus(String host);
  Future<String?> discover(String deviceId);
  void close();
}

class WifiProvisioning extends ProvisioningTransport {
  WifiProvisioning({http.Client? client}) : _client = client ?? http.Client();

  static const channel = MethodChannel('com.dentra/wifi_setup');
  static const gateway = '192.168.4.1';
  final http.Client _client;

  @override
  Future<void> joinHotspot(String setupKey) => channel.invokeMethod<void>(
        'join',
        {'password': setupKey},
      ).timeout(const Duration(seconds: 75));

  @override
  Future<void> leaveHotspot() => channel.invokeMethod<void>('leave');

  Future<Map<String, dynamic>> _read(Future<http.Response> request) async {
    final response = await request.timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException('Device request rejected');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Invalid device response');
    }
    return body;
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    final response = await _read(_client.get(Uri.http(gateway, path)));
    if (path == '/setup/info' && response['name'] is String) {
      try {
        await channel
            .invokeMethod<void>('rememberDevice', {'ssid': response['name']});
      } on MissingPluginException {
        // Android owns the temporary NetworkRequest rather than a saved SSID.
      }
    }
    return response;
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, String> body) =>
      _read(_client.post(Uri.http(gateway, path), body: body));

  @override
  Future<Map<String, dynamic>> cameraStatus(String host) {
    if (!isIpv4(host)) throw const FormatException('Invalid device address');
    return _read(_client.get(Uri.http(host, '/status')));
  }

  @override
  Future<String?> discover(String deviceId) => channel.invokeMethod<String>(
        'discover',
        {'id': deviceId},
      ).timeout(const Duration(seconds: 15));

  @override
  void close() => _client.close();
}
