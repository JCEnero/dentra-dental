import 'dart:convert';

import 'package:dentra_mobile/features/camera/services/wifi_provisioning.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('credentials are form-encoded only in POST body to the fixed gateway',
      () async {
    final requests = <http.Request>[];
    final link = WifiProvisioning(client: MockClient((request) async {
      requests.add(request);
      return http.Response('{"ok":true}', 200);
    }));
    await link.post(
        '/setup/join', {'ssid': 'Home & office', 'password': 'a+b & café'});
    final request = requests.single;
    expect(request.url.toString(), 'http://192.168.4.1/setup/join');
    expect(request.method, 'POST');
    expect(request.bodyFields,
        {'ssid': 'Home & office', 'password': 'a+b & café'});
    link.close();
  });

  test('malformed and rejected device responses do not count as success',
      () async {
    for (final response in [
      http.Response('[]', 200),
      http.Response('{"ok":false}', 403),
      http.Response('not json', 200)
    ]) {
      final link = WifiProvisioning(client: MockClient((_) async => response));
      await expectLater(link.get('/setup/info'), throwsFormatException);
      link.close();
    }
  });

  test(
      'native join passes the setup key, leaving and rediscovery use the same channel',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WifiProvisioning.channel, (call) async {
      calls.add(call);
      return call.method == 'discover' ? '192.168.1.99' : null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WifiProvisioning.channel, null));
    final link = WifiProvisioning();
    await link.joinHotspot('0123456789ABCDEF');
    await link.leaveHotspot();
    expect(await link.discover('AABBCCDD3F2A'), '192.168.1.99');
    expect(calls.map((call) => call.method), ['join', 'leave', 'discover']);
    expect(jsonEncode(calls.first.arguments), contains('0123456789ABCDEF'));
    link.close();
  });
}
