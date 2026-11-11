import 'package:dentra_mobile/features/camera/camera_strings.dart';
import 'package:dentra_mobile/features/camera/data/camera_protocol.dart';
import 'package:dentra_mobile/features/camera/data/saved_camera.dart';
import 'package:dentra_mobile/features/camera/services/camera_setup_link.dart';
import 'package:dentra_mobile/features/camera/state/camera_setup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'camera_fakes.dart';

void main() {
  late FakeSetupLink link;
  late FakeCamClient cam;
  late List<SavedCamera> saved;
  late CameraSetupController setup;
  late DateTime now;

  Future<void> wait(WidgetTester tester, Duration d) async {
    final steps = d.inMilliseconds ~/ 100;
    for (var i = 0; i < steps; i++) {
      now = now.add(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void make() {
    now = DateTime(2026, 11, 11, 9);
    link = FakeSetupLink();
    cam = FakeCamClient();
    saved = [];
    setup = CameraSetupController(
      link: link,
      clientFor: (host) => cam..commands.add('client $host'),
      onSaved: (c) async => saved.add(c),
      clock: () => now,
    );
  }

  /// Welcome → permission (granted) → power → find, scanning.
  Future<void> toFind(WidgetTester tester) async {
    setup.next();
    await tester.pump();
    expect(setup.step, SetupStep.permissions);
    expect(setup.permission, PermissionState.needed);
    await setup.allowBluetooth();
    await tester.pump();
    expect(setup.step, SetupStep.power, reason: 'moves on once allowed');
    setup.next();
    expect(setup.step, SetupStep.find);
    expect(setup.searching, isTrue);
  }

  /// …then the camera, connected, with its Wi-Fi list.
  Future<FakeSetupSession> toWifi(WidgetTester tester) async {
    await toFind(tester);
    link.scan!.add(cam3f2a);
    await tester.pump();
    expect(setup.cameras.single.name, 'Dentra Cam 3F2A');
    await setup.choose(cam3f2a);
    await tester.pump();
    expect(setup.step, SetupStep.wifi);
    final session = link.session!;
    expect(session.sent.single, {'cmd': 'scan'});
    session.emit(const NetworksEvent([
      WifiNetwork(ssid: 'Cafe', rssi: -71, secure: false),
      WifiNetwork(ssid: 'Home', rssi: -48, secure: true),
    ]));
    await tester.pump();
    expect(setup.networks.map((n) => n.ssid), ['Home', 'Cafe']);
    expect(setup.wifiLoading, isFalse);
    return session;
  }

  testWidgets('the whole way, from welcome to a saved camera', (tester) async {
    make();
    final session = await toWifi(tester);

    setup.chooseNetwork(setup.networks.first);
    await setup.join('correct horse');
    expect(setup.step, SetupStep.connect);
    expect(session.sent.last, {
      'cmd': 'connect',
      'ssid': 'Home',
      'password': 'correct horse',
    });
    expect(setup.stage, JoinStage.joining);

    session.emit(const JoinEvent(JoinState.connecting));
    session.emit(const JoinEvent(JoinState.connected, ip: '192.168.1.40'));
    await tester.pump();
    expect(setup.stage, JoinStage.restarting);
    await session.drop(); // it restarts: expected now, not an error
    await wait(tester, const Duration(seconds: 3));
    expect(setup.problem, isNull);
    await tester.pump();
    await tester.pump();
    expect(setup.stage, JoinStage.done);
    expect(cam.commands, contains('client 192.168.1.40'));

    final camera = saved.single;
    expect(camera.host, '192.168.1.40');
    expect(camera.name, 'Dentra Cam 3F2A');
    expect(camera.ssid, 'Home');
    expect(setup.saved, same(camera));
    setup.dispose();
  });

  testWidgets('a wrong password goes back to the password, saying so',
      (tester) async {
    make();
    final session = await toWifi(tester);
    setup.chooseNetwork(setup.networks.first);
    await setup.join('wrong pass');
    session.emit(const JoinEvent(
      JoinState.failed,
      error: JoinError.wrongPassword,
    ));
    await tester.pump();
    expect(setup.step, SetupStep.wifi);
    expect(setup.chosen!.ssid, 'Home', reason: 'same network, ready to retype');
    expect(setup.passwordError, CamText.errorWrongPassword);
    setup.dispose();
  });

  testWidgets('a password too short for Wi-Fi is caught before sending',
      (tester) async {
    make();
    final session = await toWifi(tester);
    setup.chooseNetwork(setup.networks.first);
    await setup.join('short');
    expect(setup.step, SetupStep.wifi);
    expect(setup.passwordError, CamText.wifiPasswordShort);
    expect(session.sent, hasLength(1), reason: 'only the scan was sent');

    // An open network needs none.
    setup.chooseNetwork(setup.networks.last);
    await setup.join('');
    expect(setup.step, SetupStep.connect);
    expect(session.sent.last['password'], '');
    setup.dispose();
  });

  testWidgets('the camera not finding the network says what to check',
      (tester) async {
    make();
    final session = await toWifi(tester);
    setup.chooseNetwork(setup.networks.first);
    await setup.join('correct horse');
    session.emit(const JoinEvent(
      JoinState.failed,
      error: JoinError.ssidNotFound,
    ));
    await tester.pump();
    expect(setup.problem, JoinProblem.ssidNotFound);
    expect(setup.canGoBack, isTrue);

    // Try again resends over the same link.
    await setup.join('correct horse');
    expect(setup.problem, isNull);
    expect(session.sent.where((c) => c['cmd'] == 'connect'), hasLength(2));
    session.emit(const JoinEvent(JoinState.failed, error: JoinError.timeout));
    await tester.pump();
    expect(setup.problem, JoinProblem.timeout);
    setup.dispose();
  });

  testWidgets('no answer within 45 s is a timeout', (tester) async {
    make();
    await toWifi(tester);
    setup.chooseNetwork(setup.networks.first);
    await setup.join('correct horse');
    await wait(tester, const Duration(seconds: 44));
    expect(setup.problem, isNull);
    await wait(tester, const Duration(seconds: 1));
    expect(setup.problem, JoinProblem.timeout);
    setup.dispose();
  });

  testWidgets('a camera that never shows up on the network: same-Wi-Fi hint',
      (tester) async {
    make();
    final session = await toWifi(tester);
    setup.chooseNetwork(setup.networks.first);
    await setup.join('correct horse');
    cam.reachable = false;
    session.emit(const JoinEvent(JoinState.connected, ip: '192.168.1.40'));
    await tester.pump();
    await wait(tester, const Duration(seconds: 3));
    expect(setup.stage, JoinStage.finding);
    await wait(tester, const Duration(seconds: 46));
    expect(setup.problem, JoinProblem.notOnNetwork);
    expect(CamText.errorNotOnNetwork(setup.ssid), contains('(Home)'));

    // Once the phone is on the right Wi-Fi, Try again finds it.
    cam.reachable = true;
    setup.findAgain();
    await tester.pump();
    await tester.pump();
    expect(setup.stage, JoinStage.done);
    expect(saved.single.host, '192.168.1.40');
    setup.dispose();
  });

  testWidgets('losing the camera before it joined says so', (tester) async {
    make();
    final session = await toWifi(tester);
    setup.chooseNetwork(setup.networks.first);
    await setup.join('correct horse');
    await session.drop();
    await tester.pump();
    expect(setup.problem, JoinProblem.linkLost);
    setup.startOver();
    expect(setup.step, SetupStep.find);
    expect(setup.searching, isTrue);
    setup.dispose();
  });

  testWidgets('nothing found in 15 s ends the search', (tester) async {
    make();
    await toFind(tester);
    await wait(tester, const Duration(seconds: 15));
    expect(setup.searching, isFalse);
    expect(setup.cameras, isEmpty);
    expect(link.scan!.hasListener, isFalse, reason: 'scan stopped');

    setup.scanAgain();
    expect(setup.searching, isTrue);
    setup.dispose();
  });

  testWidgets('a camera that will not connect says so and can be tried again',
      (tester) async {
    make();
    await toFind(tester);
    link.connectFails = true;
    link.scan!.add(cam3f2a);
    await setup.choose(cam3f2a);
    expect(setup.step, SetupStep.find);
    expect(setup.findError, CamText.findConnectFailed('Dentra Cam 3F2A'));
    expect(setup.connecting, isNull);
    setup.dispose();
  });

  testWidgets('Bluetooth refused points to Settings', (tester) async {
    make();
    link.grant = false;
    setup.next();
    await tester.pump();
    await setup.allowBluetooth();
    expect(setup.permission, PermissionState.denied);
    expect(setup.step, SetupStep.permissions);

    // Allowed in Settings, then back in the app.
    link.state = BleReadiness.ready;
    await setup.recheck();
    expect(setup.permission, PermissionState.granted);
    setup.next();
    expect(setup.step, SetupStep.power);
    setup.dispose();
  });

  testWidgets('Bluetooth off can be turned on from the guide', (tester) async {
    make();
    link.state = BleReadiness.bluetoothOff;
    setup.next();
    await tester.pump();
    expect(setup.permission, PermissionState.bluetoothOff);
    await setup.turnOnBluetooth();
    expect(setup.step, SetupStep.power);
    setup.dispose();
  });

  testWidgets('an address typed in skips Bluetooth and Wi-Fi', (tester) async {
    make();
    await toFind(tester);
    setup.useAddress('10.0.0.7');
    expect(setup.step, SetupStep.connect);
    expect(setup.manual, isTrue);
    await tester.pump();
    await tester.pump();
    expect(setup.stage, JoinStage.done);
    expect(saved.single.host, '10.0.0.7');
    expect(saved.single.ssid, isNull);
    setup.dispose();
  });

  testWidgets('back from the Wi-Fi list closes the link and searches again',
      (tester) async {
    make();
    final session = await toWifi(tester);
    setup.chooseNetwork(setup.networks.first);
    setup.back();
    expect(setup.chosen, isNull, reason: 'first back: to the list');
    setup.back();
    await tester.pump();
    expect(setup.step, SetupStep.find);
    expect(session.closed, isTrue);
    expect(setup.searching, isTrue);
    setup.dispose();
  });
}
