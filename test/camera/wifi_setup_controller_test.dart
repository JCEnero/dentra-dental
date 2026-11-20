import 'dart:async';

import 'package:dentra_mobile/features/camera/data/camera_protocol.dart';
import 'package:dentra_mobile/features/camera/data/saved_camera.dart';
import 'package:dentra_mobile/features/camera/state/wifi_setup_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wifi_setup_fakes.dart';

void main() {
  late FakeProvisioning transport;
  late WifiSetupController setup;
  late List<SavedCamera> saved;
  setUp(() {
    transport = FakeProvisioning();
    saved = [];
    setup = WifiSetupController(
        transport: transport,
        onSaved: (camera) async => saved.add(camera),
        pollInterval: const Duration(milliseconds: 1),
        joinTimeout: const Duration(milliseconds: 25),
        verifyTimeout: const Duration(milliseconds: 25));
  });
  tearDown(() => setup.dispose());

  Future<void> selectHome() async {
    await setup.next();
    await setup.connectDevice('0123456789ABCDEF');
    setup.select(setup.networks.first);
  }

  test(
      'native join, device scan, credentials, acknowledgement, identity verification, save',
      () async {
    await selectHome();
    expect(setup.networks.map((n) => n.ssid), ['Home', 'Cafe']);
    await setup.joinHome('correct horse');
    expect(transport.posts.first.$1, '/setup/join');
    expect(transport.posts.first.$2, {
      'ssid': 'Home',
      'password': 'correct horse',
      'token': FakeProvisioning.token
    });
    expect(transport.calls.indexOf('/setup/finish'),
        lessThan(transport.calls.indexOf('leave')));
    expect(saved.single.host, '192.168.1.40');
    expect(saved.single.toJson().containsKey('password'), isFalse);
    expect(setup.phase, WifiSetupPhase.ready);
  });

  test(
      'lost join and finish replies are reconciled, without resubmitting credentials',
      () async {
    await selectHome();
    transport
      ..loseJoinReply = true
      ..loseFinishReply = true;
    await setup.joinHome('correct horse');
    expect(setup.saved, isNotNull);
    expect(transport.posts.where((p) => p.$1 == '/setup/join'), hasLength(1));
  });

  for (final error in ['wrong_password', 'ssid_not_found', 'timeout']) {
    test('a reported $error is recoverable, and never completes setup',
        () async {
      await selectHome();
      transport.failure = error;
      await setup.joinHome('incorrect pass');
      expect(setup.error, isNotNull);
      expect(setup.busy, isFalse);
      expect(setup.step, WifiSetupStep.network);
      expect(saved, isEmpty);
      transport.failure = null;
      await setup.joinHome('correct horse');
      expect(saved, hasLength(1));
    });
  }

  test(
      'account verification recovers a lost DHCP handoff without resending Wi-Fi credentials',
      () async {
    transport
      ..account = true
      ..loseStatusAfterJoin = true;
    await selectHome();
    await setup.joinHome('correct horse');
    expect(saved.single.cloudId, 'cam-1');
    expect(setup.deviceJoinedHome, isTrue);
    expect(transport.posts.where((post) => post.$1 == '/setup/join'),
        hasLength(1));
  });

  test('does not save a different device at a recycled DHCP address', () async {
    await selectHome();
    transport.cameraId = '000000000000';
    await setup.joinHome('correct horse');
    expect(saved, isEmpty);
    expect(setup.deviceJoinedHome, isTrue);
    expect(setup.error, contains('same home network'));
    transport.cameraId = FakeProvisioning.id;
    await setup.verify();
    expect(saved, hasLength(1));
    expect(transport.posts.where((p) => p.$1 == '/setup/join'), hasLength(1));
  });

  test('mDNS recovers a device with a changed IP', () async {
    await selectHome();
    transport.discovered = '192.168.1.99';
    await setup.joinHome('correct horse');
    expect(saved.single.host, '192.168.1.99');
    expect(transport.calls, contains('discover ${FakeProvisioning.id}'));
  });

  test('a camera failure is not reported as setup success', () async {
    await selectHome();
    transport.cameraReady = false;
    await setup.joinHome('correct horse');
    expect(saved, isEmpty);
    expect(setup.phase, WifiSetupPhase.idle);
  });

  test('missing DHCP address never triggers handoff or success', () async {
    await selectHome();
    transport.ip = '0.invalid';
    await setup.joinHome('correct horse');
    expect(saved, isEmpty);
    expect(transport.calls, isNot(contains('/setup/finish')));
  });

  test(
      'a returning screen recovers a previously completed join without credentials',
      () async {
    transport.state = 'connected';
    await setup.next();
    await setup.connectDevice('0123456789ABCDEF');
    expect(saved.single.ssid, 'Home');
    expect(transport.posts.where((p) => p.$1 == '/setup/join'), isEmpty);
  });

  test('resume reconciles a missed join confirmation', () async {
    await selectHome();
    transport.state = 'connected';
    await setup.resume();
    expect(saved, hasLength(1));
  });

  test(
      'a failed OS release during resume leaves a recoverable verification state',
      () async {
    await selectHome();
    transport
      ..state = 'connected'
      ..leaveError = StateError('OS request lost')
      ..cameraReachable = false;
    await setup.resume();
    expect(setup.step, WifiSetupStep.finish);
    expect(setup.busy, isFalse);
    expect(setup.error, contains('same home network'));
    expect(saved, isEmpty);
  });

  test('open legacy hotspots are refused before credentials can be entered',
      () async {
    transport.protected = false;
    await setup.next();
    await setup.connectDevice('0123456789ABCDEF');
    expect(setup.step, WifiSetupStep.device);
    expect(setup.error, isNotNull);
    expect(transport.posts, isEmpty);
  });

  test('OS permission denial provides retry, no device requests', () async {
    transport.joinError = PlatformException(code: 'permission');
    await setup.next();
    await setup.connectDevice('0123456789ABCDEF');
    expect(setup.error, contains('Allow nearby Wi-Fi'));
    expect(transport.calls, ['join']);
    expect(setup.busy, isFalse);
  });

  test('duplicate taps share one in-flight join', () async {
    transport.joinGate = Completer<void>();
    await setup.next();
    final first = setup.connectDevice('0123456789ABCDEF');
    await setup.connectDevice('0123456789ABCDEF');
    expect(transport.calls, ['join']);
    transport.joinGate!.complete();
    await first;
  });

  test('older Android can verify a manually joined hotspot on retry', () async {
    transport.joinError = PlatformException(code: 'unsupported');
    await setup.next();
    await setup.connectDevice('0123456789ABCDEF');
    expect(setup.requiresManualJoin, isTrue);
    expect(setup.error, contains('Wi-Fi settings'));
    transport.joinError = null; // The user joined via system Wi-Fi settings.
    await setup.connectDevice('0123456789ABCDEF');
    expect(setup.step, WifiSetupStep.network);
    expect(transport.calls.where((call) => call == 'join'), hasLength(1));
  });

  test('closing during verification does not save a late response', () async {
    await selectHome();
    transport.statusGate = Completer<void>();
    final joining = setup.joinHome('correct horse');
    await Future<void>.delayed(Duration.zero);
    setup.dispose();
    transport.statusGate!.complete();
    await joining;
    expect(saved, isEmpty);
    expect(transport.closed, isTrue);
    // Replace the already disposed controller for tearDown.
    setup = WifiSetupController(
        transport: FakeProvisioning(), onSaved: (_) async {});
  });

  test('open home networks send an empty password', () async {
    await selectHome();
    setup.select(const WifiNetwork(ssid: 'Cafe', rssi: -80, secure: false));
    await setup.joinHome('ignored password');
    expect(transport.posts.first.$2['password'], '');
  });
}
