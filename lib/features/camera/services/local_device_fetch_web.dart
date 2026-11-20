// @dart=3.3
import 'dart:js_interop';

import 'local_device_response.dart';

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url, JSObject options);

@JS('navigator.permissions.query')
external JSPromise<_Permission> _queryPermission(JSObject descriptor);

@JS('navigator.userAgent')
external String get _userAgent;

extension type _Response(JSObject _) implements JSObject {
  external int get status;
  external JSPromise<JSString> text();
}

extension type _Permission(JSObject _) implements JSObject {
  external String get state;
}

Future<String> localNetworkPermission() async {
  try {
    final result = await _queryPermission(
      {'name': 'local-network'}.jsify() as JSObject,
    ).toDart;
    return result.state;
  } catch (_) {
    // Chrome 142 shipped the HTTP LAN exemption before granular permission
    // names. Do not query the old alias; it crashes some older renderers.
    final match = RegExp(r'(?:Chrome|Chromium)/(\d+)').firstMatch(_userAgent);
    final version = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
    return version >= 142 ? 'prompt' : 'unsupported';
  }
}

Future<LocalDeviceResponse> fetchLocalDevice(String path,
    {Map<String, String>? body}) async {
  if (!path.startsWith('/setup/')) throw ArgumentError('Invalid setup path');
  final options = <String, Object>{
    'method': body == null ? 'GET' : 'POST',
    'mode': 'cors',
    'credentials': 'omit',
    'cache': 'no-store',
    'redirect': 'error',
    'targetAddressSpace': 'local',
    if (body != null) ...{
      'headers': {'Content-Type': 'application/x-www-form-urlencoded'},
      'body': body.entries
          .map((entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
          .join('&'),
    },
  };
  final response =
      await _fetch('http://192.168.4.1$path'.toJS, options.jsify() as JSObject)
          .toDart;
  return LocalDeviceResponse(
      response.status, (await response.text().toDart).toDart);
}
