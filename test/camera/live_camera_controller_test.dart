import 'package:dentra_mobile/features/camera/data/saved_camera.dart';
import 'package:dentra_mobile/features/camera/state/live_camera_controller.dart';
import 'package:dentra_mobile/features/camera/services/dentra_cam_client.dart';
import 'package:dentra_mobile/features/scan/data/models/captured_image.dart';
import 'package:flutter_test/flutter_test.dart';

import 'camera_fakes.dart';

void main() {
  late FakeCamClient cam;
  late LiveCameraController live;
  late DateTime now;

  /// Runs fake time forward in small steps, so timers and the clock agree.
  Future<void> wait(WidgetTester tester, Duration d) async {
    final steps = d.inMilliseconds ~/ 100;
    for (var i = 0; i < steps; i++) {
      now = now.add(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void setUpLive({CameraViewSettings settings = const CameraViewSettings()}) {
    now = DateTime(2026, 11, 11, 9);
    cam = FakeCamClient();
    live = LiveCameraController(
      client: cam,
      settings: settings,
      clock: () => now,
    );
  }

  Future<void> goLive(WidgetTester tester) async {
    live.start();
    cam.stream.add(frameBytes(1));
    await tester.pump();
  }

  testWidgets('connecting until the first picture, then live with settings',
      (tester) async {
    setUpLive(settings: const CameraViewSettings(vflip: true, lightLevel: 40));
    live.start();
    expect(live.phase, LivePhase.connecting);
    expect(live.frame.value, isNull);

    cam.stream.add(frameBytes(1));
    await tester.pump();
    expect(live.phase, LivePhase.live);
    expect(live.frame.value, frameBytes(1));
    expect(cam.commands, [
      'framesize=10',
      'vflip=1',
      'hmirror=1',
      'light on 40',
    ]);

    live.dispose();
  });

  testWidgets('a dropped stream retries every 2 s and gives up at 15 s',
      (tester) async {
    setUpLive();
    await goLive(tester);

    cam.stream.addError(const DentraCamException(CamFailure.unreachable));
    await tester.pump();
    expect(live.phase, LivePhase.reconnecting);
    expect(cam.opened, 1);

    await wait(tester, const Duration(seconds: 2));
    expect(cam.opened, 2, reason: 'retried after 2 s');
    // Every attempt fails at once.
    for (var i = 0; i < 6; i++) {
      cam.stream.addError(const DentraCamException(CamFailure.unreachable));
      await wait(tester, const Duration(seconds: 2));
    }
    expect(live.phase, LivePhase.reconnecting);

    await wait(tester, const Duration(seconds: 1));
    expect(live.phase, LivePhase.disconnected);
    final attempts = cam.opened;
    await wait(tester, const Duration(seconds: 6));
    expect(cam.opened, attempts, reason: 'no more tries once disconnected');

    live.dispose();
  });

  testWidgets('a stream that never connects is disconnected after 15 s',
      (tester) async {
    setUpLive();
    live.start();
    await wait(tester, const Duration(seconds: 14));
    expect(live.phase, LivePhase.connecting);
    await wait(tester, const Duration(seconds: 1));
    expect(live.phase, LivePhase.disconnected);

    live.dispose();
  });

  testWidgets('retry starts over with a fresh 15 s', (tester) async {
    setUpLive();
    live.start();
    await wait(tester, const Duration(seconds: 15));
    expect(live.phase, LivePhase.disconnected);

    live.retry();
    expect(live.phase, LivePhase.connecting);
    cam.stream.add(frameBytes(2));
    await tester.pump();
    expect(live.phase, LivePhase.live);

    live.dispose();
  });

  testWidgets('a stream that goes quiet counts as dropped', (tester) async {
    setUpLive();
    await goLive(tester);
    await wait(tester, const Duration(seconds: 2));
    expect(live.phase, LivePhase.live);
    await wait(tester, const Duration(milliseconds: 1600));
    expect(live.phase, LivePhase.reconnecting);

    live.dispose();
  });

  testWidgets('the picture holds still while a photo is taken', (tester) async {
    setUpLive();
    await goLive(tester);

    final photo = live.capture();
    expect(live.capturing, isTrue);
    cam.stream.add(frameBytes(2));
    await tester.pump();
    expect(live.frame.value, frameBytes(1), reason: 'frozen');
    // The camera may stall the stream while it takes the photo.
    await wait(tester, const Duration(seconds: 5));
    expect(live.phase, LivePhase.live);

    cam.pendingCapture!.complete(frameBytes(9));
    final image = await photo;
    expect(image.source, CaptureSource.device);
    expect(image.bytes, frameBytes(9));
    expect(image.deviceMeta, containsPair('res', 'UXGA'));
    expect(cam.commands, contains('capture UXGA light=true'));
    expect(live.capturing, isFalse);

    cam.stream.add(frameBytes(3));
    await tester.pump();
    expect(live.frame.value, frameBytes(3));

    live.dispose();
  });

  testWidgets('signal strength is read every 5 s', (tester) async {
    setUpLive();
    await goLive(tester);
    await tester.pump();
    expect(live.signal, 4);

    cam.rssi = -80;
    await wait(tester, const Duration(seconds: 5));
    expect(live.signal, 1);

    cam.reachable = false;
    await wait(tester, const Duration(seconds: 5));
    expect(live.signal, isNull);
    // Pictures still arriving keep it live; the dot follows the stream.
    cam.stream.add(frameBytes(4));
    await tester.pump();
    expect(live.isLive, isTrue);

    live.dispose();
  });

  testWidgets('stop closes the stream and turns the light off',
      (tester) async {
    setUpLive();
    await goLive(tester);
    final stream = cam.stream;
    live.stop();
    await tester.pump();
    expect(stream.hasListener, isFalse);
    expect(cam.commands.last, 'light off 60');

    final polls = cam.statusCalls;
    await wait(tester, const Duration(seconds: 10));
    expect(cam.statusCalls, polls, reason: 'no polling while stopped');
    expect(cam.opened, 1, reason: 'no reconnecting while stopped');

    live.start();
    expect(cam.opened, 2);

    live.dispose();
  });

  testWidgets('a camera without a light gets no light commands',
      (tester) async {
    setUpLive();
    cam.lightAvailable = false;
    live.start();
    await tester.pump();
    expect(live.lightAvailable, isFalse);
    cam.stream.add(frameBytes(1));
    await tester.pump();
    expect(cam.commands, ['framesize=10', 'vflip=1', 'hmirror=1']);

    live.stop();
    await tester.pump();
    expect(cam.commands.where((c) => c.startsWith('light')), isEmpty);
    live.dispose();
  });

  testWidgets('settings show at once, are kept, and reach the camera',
      (tester) async {
    setUpLive();
    final kept = <CameraViewSettings>[];
    live.dispose();
    live = LiveCameraController(
      client: cam,
      settings: const CameraViewSettings(),
      onSettingsChanged: kept.add,
      clock: () => now,
    );
    await goLive(tester);
    cam.commands.clear();

    expect(await live.rotate(), isTrue);
    // Upright by default, so a rotate turns both flips off.
    expect(live.settings.vflip || live.settings.hmirror, isFalse);
    expect(await live.mirror(), isTrue);
    expect(live.settings.hmirror, isTrue);
    expect(await live.setLight(level: 85), isTrue);
    expect(cam.commands, [
      'vflip=0',
      'hmirror=0',
      'hmirror=1',
      'light on 85',
    ]);
    expect(kept.last.lightLevel, 85);

    live.dispose();
  });
}
