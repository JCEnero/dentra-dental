// @dart=3.3
// dart compile js -o /tmp/dentra-fetch-check.js tool/check_browser_setup_fetch.dart
// node --require ./test/camera/browser_fetch_mock.cjs /tmp/dentra-fetch-check.js
import 'dart:js_interop';

import 'package:dentra_mobile/features/camera/services/local_device_fetch_web.dart';

@JS('console.log')
external void log(String message);

@JS('dentraPermission')
external set permission(String value);
@JS('dentraQueryThrows')
external set queryThrows(bool value);
@JS('dentraAgent')
external set agent(String value);
@JS('dentraRecordedRequest')
external JSObject get recordedRequest;

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  check(await localNetworkPermission() == 'granted',
      'Granted permission was lost');
  permission = 'denied';
  check(await localNetworkPermission() == 'denied',
      'Denied permission was ignored');
  queryThrows = true;
  check(await localNetworkPermission() == 'prompt',
      'Chrome legacy-granularity fallback failed');
  agent = 'Mozilla/5.0 Version/26.0 Safari/605.1.15';
  check(await localNetworkPermission() == 'unsupported',
      'Unsupported browser was accepted');

  final response = await fetchLocalDevice('/setup/join', body: {
    'ssid': 'Home & office',
    'password': 'a+b & café',
    'code': 'K7P2QX',
  });
  check(response.status == 200 && response.body == '{"ok":true}',
      'Response parsing failed');
  final request = recordedRequest.dartify() as Map;
  final options = request['options'] as Map;
  check(request['url'] == 'http://192.168.4.1/setup/join',
      'Unexpected local target');
  check(options['targetAddressSpace'] == 'local',
      'Missing Local Network Access annotation');
  check(options['mode'] == 'cors' && options['credentials'] == 'omit',
      'Unsafe cross-origin credentials');
  check(options['redirect'] == 'error',
      'Local credential request followed redirects');
  final fields = Uri.splitQueryString(options['body'] as String);
  check(fields['password'] == 'a+b & café' && fields['ssid'] == 'Home & office',
      'Form encoding changed credentials');
  check(!(request['url'] as String).contains('password'),
      'Credentials escaped into URL');

  await fetchLocalDevice('/setup/info');
  final getOptions = (recordedRequest.dartify() as Map)['options'] as Map;
  check(getOptions['method'] == 'GET' && !getOptions.containsKey('body'),
      'GET request included a body');
  var refused = false;
  try {
    await fetchLocalDevice('/anything-else');
  } on ArgumentError {
    refused = true;
  }
  check(refused, 'Arbitrary local endpoint was accepted');
  log('Browser JS interop checks passed: permission, supported-browser fallback, fixed target, local address space, CORS, credential isolation, encoding, and redirects.');
}
