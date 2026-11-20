import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dentra_mobile/features/camera/providers/camera_providers.dart';
import 'package:dentra_mobile/features/camera/screens/wifi_setup_screen.dart';
import 'dart:convert';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/camera/data/saved_camera.dart';
import 'package:dentra_mobile/features/camera/services/browser_wifi_provisioning.dart';
import 'package:dentra_mobile/features/camera/services/cloud_cam_api.dart';
import 'package:dentra_mobile/features/camera/services/dentra_cam_client.dart';
import 'package:dentra_mobile/features/camera/services/local_device_response.dart';
import 'package:dentra_mobile/features/camera/services/wifi_provisioning.dart';
import 'package:dentra_mobile/features/camera/state/wifi_setup_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'camera_fakes.dart';
import 'wifi_setup_fakes.dart';
import 'package:dentra_mobile/features/camera/services/account_wifi_provisioning.dart';

const hardwareId = 'AABBCCDD3F2A';
const token = '0123456789abcdef0123456789abcdef';

class BrowserSetupServer {
  final localCalls = <(String, Map<String, String>?)>[];
  final apiCalls = <String>[];
  String pairingState = 'claimed';
  String linkedHardwareId = hardwareId;
  bool online = true;
  bool oldFirmware = false;
  bool joined = false;
  String? session;
  bool expiredAtCreation = false;

  CloudCamApi get api => CloudCamApi(ApiClient(
      baseUrl: 'https://api.example',
      accessToken: () async => 'test-token',
      client: MockClient((request) async {
        apiCalls.add('${request.method} ${request.url.path}');
        if (request.method == 'POST') {
          return http.Response(
              jsonEncode({
                'pairing': {
                  'id': 'pairing-1',
                  'code': 'K7P2QX',
                  'expires_at': DateTime.now()
                      .add(Duration(minutes: expiredAtCreation ? -1 : 15))
                      .toIso8601String(),
                }
              }),
              201);
        }
        return http.Response(
            jsonEncode({
              'pairing': {
                'id': 'pairing-1',
                'status': pairingState,
                'device': {
                  'id': 'cloud-camera-1',
                  'hardware_id': linkedHardwareId,
                  'name': 'Dentra Cam 3F2A',
                  'online': online
                },
              }
            }),
            200);
      })));

  Future<LocalDeviceResponse> fetch(String path,
      {Map<String, String>? body}) async {
    localCalls.add((path, body));
    final Map<String, dynamic> data;
    switch (path) {
      case '/setup/info':
        data = {
          'id': hardwareId,
          'name': 'Dentra Cam 3F2A',
          'protocol': oldFirmware ? 1 : 2,
          'browser_setup': !oldFirmware,
          'session_setup': !oldFirmware,
          'protected': true,
          'token': token
        };
      case '/setup/status':
        data = {
          'id': hardwareId,
          'ssid': 'Home',
          'state': joined ? 'connected' : 'idle',
          'ip': '192.168.1.40'
        };
      case '/setup/networks':
        data = {
          'networks': [
            {'ssid': 'Home', 'rssi': -48, 'secure': true}
          ]
        };
      case '/setup/join':
        session = body?['session'];
        joined = true;
        data = {'ok': true};
      case '/setup/finish':
        data = {'ok': true};
      default:
        throw StateError('Unexpected local endpoint');
    }
    return LocalDeviceResponse(200, jsonEncode(data));
  }
}

class ReadyCloudCamera extends FakeCamClient {
  bool ready = true;
  bool closed = false;
  String? Function()? sessionFor;
  @override
  Future<CamStatus> status(
          {Duration timeout = const Duration(seconds: 3)}) async =>
      CamStatus(
          deviceId: hardwareId,
          cameraReady: ready,
          setupSession: sessionFor?.call());
  @override
  void close() {
    closed = true;
  }
}

void main() {
  late BrowserSetupServer server;
  late ReadyCloudCamera camera;
  late BrowserWifiProvisioning transport;
  setUp(() {
    server = BrowserSetupServer();
    camera = ReadyCloudCamera()..sessionFor = () => server.session;
    transport = BrowserWifiProvisioning(
        api: server.api,
        clientFor: (_) => camera,
        fetch: server.fetch,
        permission: () async => 'prompt');
  });
  tearDown(() => transport.close());

  test(
      'signed-in mobile builds select native Wi-Fi even when cameras use the cloud',
      () {
    final container = ProviderContainer(overrides: [
      camLinkProvider.overrideWithValue(CamLink.cloud),
      cloudCamApiProvider.overrideWithValue(server.api),
      cloudCamClientFactoryProvider.overrideWithValue((_) => camera),
    ]);
    final link = container.read(wifiProvisioningProvider)();
    expect(link, isA<AccountWifiProvisioning>());
    expect(link.usesBrowserWifi, isFalse);
    expect(link.linksAccount, isTrue);
    link.close();
    container.dispose();
  });

  test(
      'browser setup prepares an account session before contacting local Wi-Fi',
      () async {
    await transport.prepare();
    expect(server.apiCalls, ['POST /api/cam/pairings']);
    expect(server.localCalls, isEmpty);
    await transport.prepare();
    expect(server.apiCalls, hasLength(1),
        reason: 'Retry reuses its unexpired session');
  });

  test(
      'credentials and account code are sent together, without manual code entry',
      () async {
    await transport.prepare();
    await transport.get('/setup/info');
    await transport.post('/setup/join',
        {'ssid': 'Home', 'password': 'a+b & café', 'token': token});
    expect(server.localCalls.last.$2, {
      'ssid': 'Home',
      'password': 'a+b & café',
      'token': token,
      'code': 'K7P2QX',
      'session': server.session,
    });
    expect(server.session, matches(RegExp(r'^[a-f0-9]{24}$')));
  });

  test(
      'controller completes browser setup only after matching relay camera responds',
      () async {
    final saved = <SavedCamera>[];
    final setup = WifiSetupController(
        transport: transport,
        onSaved: (camera) async => saved.add(camera),
        pollInterval: const Duration(milliseconds: 1));
    await setup.next();
    expect(setup.step, WifiSetupStep.device);
    await setup.connectDevice('');
    setup.select(setup.networks.single);
    await setup.joinHome('correct horse');
    expect(setup.phase, WifiSetupPhase.ready);
    expect(saved.single.cloudId, 'cloud-camera-1');
    expect(saved.single.host, isNull,
        reason: 'Browser captures continue through HTTPS relay');
    expect(
        server.localCalls.map((c) => c.$1),
        containsAllInOrder([
          '/setup/info',
          '/setup/status',
          '/setup/networks',
          '/setup/join',
          '/setup/status',
          '/setup/finish'
        ]));
    setup.dispose();
  });

  test(
      'native account setup joins through the native transport and saves a verified cloud camera',
      () async {
    final native = FakeProvisioning();
    camera.sessionFor = () => native.posts
        .where((post) => post.$1 == '/setup/join')
        .firstOrNull
        ?.$2['session'];
    final link = AccountWifiProvisioning(
        transport: native, api: server.api, clientFor: (_) => camera);
    final saved = <SavedCamera>[];
    final setup = WifiSetupController(
        transport: link,
        onSaved: (value) async => saved.add(value),
        pollInterval: const Duration(milliseconds: 1));
    expect(link.usesBrowserWifi, isFalse);
    expect(link.linksAccount, isTrue);
    await setup.next();
    await setup.connectDevice('0123456789ABCDEF');
    expect(native.calls, contains('join'));
    setup.select(setup.networks.first);
    await setup.joinHome('correct horse');
    expect(native.posts.first.$2['code'], 'K7P2QX');
    expect(
        native.posts.first.$2['session'], matches(RegExp(r'^[a-f0-9]{24}$')));
    expect(saved.single.cloudId, 'cloud-camera-1');
    expect(saved.single.host, isNull);
    expect(server.localCalls, isEmpty,
        reason: 'Native setup must never use browser fetch');
    setup.dispose();
    expect(native.closed, isTrue);
    expect(camera.closed, isTrue);
  });

  test('a live camera from an earlier setup session cannot complete this setup',
      () async {
    await transport.prepare();
    await transport.get('/setup/info');
    await transport
        .post('/setup/join', {'ssid': 'Home', 'password': 'correct horse'});
    final current = server.session;
    camera.sessionFor = () => '000000000000000000000000';
    expect((await transport.cameraStatus(''))['camera_ok'], isFalse);
    camera.sessionFor = () => current;
    expect((await transport.cameraStatus(''))['camera_ok'], isTrue);
  });

  test('a pending account link never counts as camera readiness', () async {
    await transport.prepare();
    await transport.get('/setup/info');
    server.pairingState = 'pending';
    await expectLater(
        transport.cameraStatus('192.168.1.40'), throwsFormatException);
  });

  test('a camera linked with a different hardware identity is rejected',
      () async {
    await transport.prepare();
    await transport.get('/setup/info');
    server.linkedHardwareId = '000000000000';
    await expectLater(transport.cameraStatus('192.168.1.40'),
        throwsA(isA<ProvisioningException>()));
  });

  test('a claimed but offline device never completes setup', () async {
    await transport.prepare();
    await transport.get('/setup/info');
    server.online = false;
    await expectLater(
        transport.cameraStatus('192.168.1.40'), throwsFormatException);
  });

  test('relay camera_ok=false remains a failure to verify', () async {
    await transport.prepare();
    await transport.get('/setup/info');
    camera.ready = false;
    expect(
        (await transport.cameraStatus('192.168.1.40'))['camera_ok'], isFalse);
  });

  test('expired sessions do not transmit credentials', () async {
    server.expiredAtCreation = true;
    await transport.prepare();
    await expectLater(
        transport
            .post('/setup/join', {'ssid': 'Home', 'password': 'secret pass'}),
        throwsA(isA<ProvisioningException>()));
    expect(server.localCalls, isEmpty);
  });

  test('firmware without browser CORS support is reported clearly', () async {
    server.oldFirmware = true;
    await expectLater(
        transport.get('/setup/info'), throwsA(isA<ProvisioningException>()));
  });

  test('denied browser permission blocks setup without an API call', () async {
    final denied = BrowserWifiProvisioning(
        api: server.api,
        clientFor: (_) => camera,
        permission: () async => 'denied',
        fetch: server.fetch);
    await expectLater(denied.prepare(), throwsA(isA<ProvisioningException>()));
    expect(server.apiCalls, isEmpty);
    expect(server.localCalls, isEmpty);
    denied.close();
  });

  test('closing browser provisioning closes the verification socket', () async {
    await transport.prepare();
    await transport.get('/setup/info');
    await transport.cameraStatus('192.168.1.40');
    transport.close();
    expect(camera.closed, isTrue);
  });

  test('unsupported browsers are identified before the user switches Wi-Fi',
      () async {
    final unsupported = BrowserWifiProvisioning(
        api: server.api,
        clientFor: (_) => camera,
        permission: () async => 'unsupported',
        fetch: server.fetch);
    await expectLater(
        unsupported.prepare(), throwsA(isA<ProvisioningException>()));
    expect(server.apiCalls, isEmpty);
    expect(server.localCalls, isEmpty);
    unsupported.close();
  });
}
