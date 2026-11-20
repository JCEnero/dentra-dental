import 'dart:async';
import 'dart:convert';

import 'account_wifi_provisioning.dart';
import 'local_device_response.dart';
import 'local_device_fetch_stub.dart'
    if (dart.library.js_interop) 'local_device_fetch_web.dart' as browser;
import 'wifi_provisioning.dart';

typedef LocalDeviceFetch = Future<LocalDeviceResponse> Function(String path,
    {Map<String, String>? body});

/// Browser builds keep setup inside Dentra, using permission-gated local fetch.
/// Joining Wi-Fi still belongs to system settings on a browser.
class BrowserWifiProvisioning extends AccountWifiProvisioning {
  BrowserWifiProvisioning({
    required super.api,
    required super.clientFor,
    LocalDeviceFetch? fetch,
    Future<String> Function()? permission,
  }) : super(
            transport: _BrowserTransport(
                fetch: fetch ?? browser.fetchLocalDevice,
                permission: permission ?? browser.localNetworkPermission));
}

class _BrowserTransport extends ProvisioningTransport {
  _BrowserTransport({required this.fetch, required this.permission});
  final LocalDeviceFetch fetch;
  final Future<String> Function() permission;
  bool _closed = false;
  @override
  bool get usesBrowserWifi => true;

  @override
  Future<void> prepare() async {
    final status = await permission();
    if (status == 'unsupported') {
      throw const ProvisioningException(
          'This browser blocks in-app device setup. Open Dentra in current Chrome or Edge on Android or a computer, or use the installed Dentra app.');
    }
    if (status == 'denied') {
      throw const ProvisioningException(
          'Allow Local network access in this browser’s site settings, then try again.');
    }
  }

  @override
  Future<void> joinHotspot(String setupKey) => prepare();

  Future<Map<String, dynamic>> _request(String path,
      {Map<String, String>? body}) async {
    if (_closed) throw StateError('Setup closed');
    final response =
        await fetch(path, body: body).timeout(const Duration(seconds: 10));
    if (_closed) throw StateError('Setup closed');
    if (response.status < 200 || response.status >= 300) {
      throw const FormatException('Device rejected request');
    }
    final result = jsonDecode(response.body);
    if (result is! Map<String, dynamic>) {
      throw const FormatException('Invalid device response');
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> get(String path) => _request(path);
  @override
  Future<Map<String, dynamic>> post(String path, Map<String, String> body) =>
      _request(path, body: body);
  @override
  Future<void> leaveHotspot() async {}
  @override
  Future<String?> discover(String deviceId) async => null;
  @override
  Future<Map<String, dynamic>> cameraStatus(String host) =>
      throw UnsupportedError('Verification uses the account relay');
  @override
  void close() {
    _closed = true;
  }
}
