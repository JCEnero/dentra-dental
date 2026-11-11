import 'dart:convert';

import 'package:dentra_mobile/features/camera/camera_flow.dart';
import 'package:dentra_mobile/features/camera/camera_strings.dart';
import 'package:dentra_mobile/features/camera/data/camera_protocol.dart';
import 'package:dentra_mobile/features/camera/data/saved_camera.dart';
import 'package:dentra_mobile/features/camera/providers/camera_providers.dart';
import 'package:dentra_mobile/features/camera/screens/live_capture_screen.dart';
import 'package:dentra_mobile/features/camera/widgets/camera_bits.dart';
import 'package:dentra_mobile/features/scan/data/models/captured_image.dart';
import 'package:dentra_mobile/features/scan/providers/scan_session_provider.dart';
import 'package:dentra_mobile/features/scan/screens/scan_screen.dart';
import 'package:dentra_mobile/features/scan/services/phone_camera_service.dart';
import 'package:dentra_mobile/features/scan/services/photo_check_service.dart';
import 'package:dentra_mobile/features/scan/services/screening_analysis_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_fakes.dart';

Future<void> settle(WidgetTester tester, {int steps = 8}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await settle(tester);
}

class _PhoneCamera extends PhoneCameraService {
  @override
  bool get supportsCamera => true;

  @override
  Future<CapturedImage?> capture(CaptureSource source) async => null;
}

final _camera = SavedCamera(
  host: '192.168.1.40',
  name: 'Dentra Cam 3F2A',
  ssid: 'Home',
  savedAt: DateTime(2026, 11, 11),
);

/// An app with one button that runs [open].
Future<void> pumpLauncher(
  WidgetTester tester,
  ProviderContainer container,
  Future<void> Function(BuildContext) open, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tapText(tester, 'open');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (name, size, scale) in [
    ('small phone, large text', const Size(320, 568), 1.3),
    ('standard phone', const Size(390, 844), 1.0),
    ('large phone, accessibility text', const Size(430, 932), 2.0),
  ]) {
    testWidgets('the setup guide, from welcome to a working camera: $name',
        (tester) async {
      final link = FakeSetupLink();
      final cam = FakeCamClient();
      final container = ProviderContainer(overrides: [
        cameraSetupLinkProvider.overrideWithValue(link),
        camClientFactoryProvider.overrideWithValue((_) => cam),
      ]);
      addTearDown(container.dispose);
      SetupOutcome? outcome;
      await pumpLauncher(
        tester,
        container,
        (context) async => outcome = await openCameraSetup(context),
        size: size,
        textScale: scale,
      );

      expect(find.text(CamText.welcomeTitle), findsOneWidget);
      expect(find.text('1 of 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapText(tester, CamText.welcomeStart);

      expect(find.text(CamText.permissionTitle), findsWidgets);
      await tapText(tester, CamText.permissionAllow);
      expect(link.permissionRequests, 1);
      // Allowed: on to the next step by itself.
      expect(find.text(CamText.powerTitle), findsOneWidget);
      expect(find.text('3 of 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapText(tester, CamText.powerReady);

      expect(find.text(CamText.findSearching), findsOneWidget);
      link.scan!.add(cam3f2a);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Dentra Cam 3F2A');

      expect(find.text(CamText.wifiTitle), findsOneWidget);
      link.session!.emit(const NetworksEvent([
        WifiNetwork(ssid: 'Cafe', rssi: -71, secure: false),
        WifiNetwork(ssid: 'Home', rssi: -48, secure: true),
      ]));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tapText(tester, CamText.wifiNotListed);
      expect(find.text(CamText.wifiNotListedTips.first), findsOneWidget);
      await tapText(tester, 'Home');

      await tester.enterText(find.byType(TextField), 'correct horse');
      await tapText(tester, CamText.wifiConnect);
      expect(link.session!.sent.last['ssid'], 'Home');
      expect(find.text(CamText.stageJoining), findsOneWidget);
      expect(tester.takeException(), isNull);

      link.session!.emit(
          const JoinEvent(JoinState.connected, ip: '192.168.1.40'));
      await settle(tester, steps: 40);
      expect(find.text(CamText.successTitle), findsOneWidget);
      // The live preview test streams from the new camera.
      cam.stream.add(frameBytes(1));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(
        container.read(savedCameraProvider).valueOrNull?.host,
        '192.168.1.40',
      );

      await tapText(tester, CamText.startCapturing);
      expect(outcome, SetupOutcome.startCapturing);
    });

    testWidgets('the live camera: capture, check, skip, review, save: $name',
        (tester) async {
      final cam = FakeCamClient();
      final check = FakePhotoCheck();
      final container = ProviderContainer(overrides: [
        camClientFactoryProvider.overrideWithValue((_) => cam),
        photoCheckServiceProvider.overrideWithValue(check),
      ]);
      addTearDown(container.dispose);
      container.read(scanSessionProvider.notifier).start();
      bool? saved;
      await pumpLauncher(
        tester,
        container,
        (context) async => saved = await Navigator.of(context).push(
          LiveCaptureScreen.route(
            camera: _camera,
            settings: const CameraViewSettings(),
          ),
        ),
        size: size,
        textScale: scale,
      );

      expect(find.text(CamText.connecting), findsOneWidget);
      expect(find.text('1 of 9'), findsOneWidget);
      cam.stream.add(frameBytes(1));
      await settle(tester);
      expect(find.text(CamText.connecting), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(ShutterButton));
      await tester.pump();
      expect(cam.commands, contains('capture UXGA light=true'));
      cam.pendingCapture!.complete(frameBytes(9));
      await settle(tester);
      // On to the next area while the photo is checked.
      expect(find.text('2 of 9'), findsOneWidget);
      expect(container.read(scanSessionProvider).captures, isEmpty);
      check.pass();
      await settle(tester);
      expect(container.read(scanSessionProvider).captures.keys, ['front']);
      expect(tester.takeException(), isNull);

      // A dropped stream shows it's reconnecting.
      cam.stream.addError(StateError('gone'));
      await settle(tester, steps: 2);
      expect(find.text(CamText.reconnecting), findsOneWidget);
      cam.stream.add(frameBytes(2));
      await settle(tester, steps: 25);
      cam.stream.add(frameBytes(3));
      await settle(tester, steps: 5);
      expect(find.text(CamText.reconnecting), findsNothing);

      // Skipping the rest opens the review by itself.
      for (var i = 0; i < 8; i++) {
        await tapText(tester, CamText.skip);
      }
      expect(find.text(CamText.reviewTitle), findsOneWidget);
      expect(find.text(CamText.reviewSummary(1, 9)), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapText(tester, CamText.saveAndAnalyze);
      expect(saved, isTrue);
    });
  }

  testWidgets('the live camera says when it is gone, and offers Retry',
      (tester) async {
    final cam = FakeCamClient();
    final container = ProviderContainer(overrides: [
      camClientFactoryProvider.overrideWithValue((_) => cam),
      photoCheckServiceProvider.overrideWithValue(FakePhotoCheck()),
    ]);
    addTearDown(container.dispose);
    container.read(scanSessionProvider.notifier).start();
    await pumpLauncher(
      tester,
      container,
      (context) => Navigator.of(context).push(LiveCaptureScreen.route(
        camera: _camera,
        settings: const CameraViewSettings(),
      )),
    );
    await settle(tester, steps: 155);
    expect(find.text(CamText.disconnectedTitle), findsOneWidget);
    expect(find.text(CamText.checkDevice), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tapText(tester, CamText.retry);
    cam.stream.add(frameBytes(1));
    await settle(tester);
    expect(find.text(CamText.disconnectedTitle), findsNothing);
  });

  group('the scan tab', () {
    Future<ProviderContainer> pumpScanTab(
      WidgetTester tester, {
      FakeSetupLink? link,
      FakeCamClient? cam,
      bool camAvailable = true,
    }) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [
        dentraCamAvailableProvider.overrideWithValue(camAvailable),
        cameraSetupLinkProvider.overrideWithValue(link ?? FakeSetupLink()),
        camClientFactoryProvider
            .overrideWithValue((_) => cam ?? FakeCamClient()),
        phoneCameraServiceProvider.overrideWithValue(_PhoneCamera()),
        photoCheckServiceProvider.overrideWithValue(FakePhotoCheck()),
        screeningAnalysisServiceProvider.overrideWithValue(null),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ScanScreen())),
      ));
      await settle(tester, steps: 3);
      return container;
    }

    /// Start, skip the check-in, then pick [choice] from the sheet.
    Future<void> startScan(WidgetTester tester, String choice) async {
      await tapText(tester, 'Start scan');
      await tapText(tester, 'Skip for now');
      expect(find.text(CamText.choiceTitle), findsOneWidget);
      await tapText(tester, choice);
    }

    testWidgets('choosing the Dentra Cam without one opens the setup guide',
        (tester) async {
      await pumpScanTab(tester);
      expect(find.text(CamText.cardNotSetUpTitle), findsOneWidget);

      await startScan(tester, CamText.choiceCam);
      expect(find.text(CamText.welcomeTitle), findsOneWidget);
      await tapText(tester, CamText.welcomeLater);
      // The scan carries on with the phone's own camera.
      expect(find.text(CamText.welcomeTitle), findsNothing);
      expect(find.text('Take photo'), findsOneWidget);

      await tapText(tester, CamText.cardSetUp);
      expect(find.text(CamText.welcomeTitle), findsOneWidget);
      await tester.tap(find.byTooltip(CamText.closeSetup));
      await settle(tester);
      expect(find.text(CamText.welcomeTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with a camera set up, the scan captures in its live view',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'dentra_cam.v1.camera': jsonEncode(_camera.toJson()),
      });
      final cam = FakeCamClient();
      await pumpScanTab(tester, cam: cam);
      await startScan(tester, CamText.choiceCam);

      // Tips first, with "Don't show again".
      expect(find.text(CamText.tipsTitle), findsOneWidget);
      await tapText(tester, CamText.tipsDontShow);
      await tapText(tester, CamText.tipsGotIt);
      expect(find.text(CamText.connecting), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip(CamText.closeCamera));
      await settle(tester);
      expect(find.text(CamText.connecting), findsNothing);
      // Closing checks the camera, so the card shows it's there.
      expect(find.text('Connected'), findsOneWidget);

      await tapText(tester, 'Capture with device');
      expect(find.text(CamText.connecting), findsOneWidget);
      expect(find.text(CamText.tipsTitle), findsNothing, reason: 'hidden now');
      await tester.tap(find.byTooltip(CamText.closeCamera));
      await settle(tester);
    });
  
    testWidgets('choosing your own camera skips the Dentra Cam, even set up',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'dentra_cam.v1.camera': jsonEncode(_camera.toJson()),
      });
      final cam = FakeCamClient();
      await pumpScanTab(tester, cam: cam);
      await startScan(tester, CamText.choiceOwn);
      expect(find.text(CamText.tipsTitle), findsNothing);
      expect(find.text(CamText.connecting), findsNothing);
      expect(find.text('Take photo'), findsOneWidget);
      expect(cam.opened, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a Dentra Cam scan can switch to your own camera',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'dentra_cam.v1.camera': jsonEncode(_camera.toJson()),
        'dentra_cam.v1.tips_hidden': true,
      });
      await pumpScanTab(tester);
      await startScan(tester, CamText.choiceCam);
      await tester.tap(find.byTooltip(CamText.closeCamera));
      await settle(tester);
      expect(find.text('Capture with device'), findsOneWidget);

      await tester.tap(find.byTooltip('Use my own camera'));
      await settle(tester);
      expect(find.text('Take photo'), findsOneWidget);
    });

    testWidgets('on the website the Dentra Cam is listed but not offered',
        (tester) async {
      await pumpScanTab(tester, camAvailable: false);
      await tapText(tester, 'Start scan');
      await tapText(tester, 'Skip for now');
      expect(find.text(CamText.choiceCamAppOnly), findsOneWidget);
      await tester.tap(find.text(CamText.choiceCam));
      await settle(tester);
      expect(find.text(CamText.choiceTitle), findsOneWidget,
          reason: "can't be chosen here");

      await tapText(tester, CamText.choiceOwn);
      expect(find.text(CamText.choiceTitle), findsNothing);
      expect(find.text('Take photo'), findsOneWidget);
    });
});
}
