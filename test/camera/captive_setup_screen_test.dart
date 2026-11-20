import 'package:dentra_mobile/features/camera/camera_flow.dart';
import 'package:dentra_mobile/features/camera/providers/camera_providers.dart';
import 'package:dentra_mobile/features/camera/screens/wifi_setup_screen.dart';
import 'package:dentra_mobile/features/camera/services/cloud_cam_api.dart';
import 'package:dentra_mobile/features/camera/services/dentra_cam_client.dart';
import 'package:dentra_mobile/features/camera/widgets/camera_connection_art.dart';
import 'package:dentra_mobile/features/auth/widgets/dentra_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_fakes.dart';
import 'hotspot_setup_test.dart' show FakeCamApi;

class LocalPortalCamera extends FakeCamClient {
  bool ready = false;
  bool closed = false;

  @override
  Future<CamStatus> status(
          {Duration timeout = const Duration(seconds: 3)}) async =>
      CamStatus(deviceId: 'AABBCCDD3F2A', cameraReady: ready);

  @override
  void close() => closed = true;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (size, scale) in [
    (const Size(320, 568), 1.3),
    (const Size(390, 844), 1.0),
    (const Size(430, 932), 2.0),
  ]) {
    testWidgets(
        'single connection card and confirmed account link at $size/$scale',
        (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final server = FakeCamApi();
      final container = ProviderContainer(overrides: [
        camLinkProvider.overrideWithValue(CamLink.cloud),
        cloudCamApiProvider.overrideWithValue(server.api),
        cloudCamerasProvider.overrideWith((ref) async =>
            server.status == 'claimed'
                ? [
                    const CloudCamera(
                        id: 'cam-1', name: 'Dentra Cam 3F2A', online: true)
                  ]
                : []),
        wifiProvisioningProvider.overrideWithValue(
            () => throw StateError('The app must not provision Wi-Fi')),
      ]);
      addTearDown(container.dispose);
      SetupOutcome? result;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (_, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: scale, maxScaleFactor: scale, child: child!),
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async =>
                            result = await openCameraSetup(context),
                        child: const Text('Connect')),
                  )),
        ),
      ));
      await tester.tap(find.text('Connect'));
      await settle(tester);
      expect(find.text('K7P 2QX'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DentraLogo), findsOneWidget);
      expect(find.byType(CameraConnectionArt), findsOneWidget);
      expect(find.textContaining('No password needed.'), findsOneWidget);
      expect(find.textContaining('setup key'), findsNothing);
      await tester.ensureVisible(find.text('Setup page didn’t open?'));
      await tester.tap(find.text('Setup page didn’t open?'));
      await settle(tester);
      expect(find.text('http://192.168.4.1/'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Your camera is linked.'), findsNothing);
      expect(tester.takeException(), isNull);
      server.status = 'claimed';
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('Your camera is linked.'), findsOneWidget);
      expect(container.read(savedCameraProvider).valueOrNull?.cloudId, 'cam-1');
      await tester.ensureVisible(find.text('Start capturing'));
      await tester.tap(find.text('Start capturing'));
      await settle(tester);
      expect(result, SetupOutcome.startCapturing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('3D guide respects reduced motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
              child: SizedBox(width: 300, child: CameraConnectionArt()))),
    ));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local fallback checks camera readiness before saving',
      (tester) async {
    final camera = LocalPortalCamera();
    final container = ProviderContainer(overrides: [
      camLinkProvider.overrideWithValue(CamLink.local),
      cloudCamApiProvider.overrideWithValue(null),
      camClientFactoryProvider.overrideWithValue((_) => camera),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => openCameraSetup(context),
                        child: const Text('Connect')),
                  ))),
    ));
    await tester.tap(find.text('Connect'));
    await settle(tester);
    await tester.ensureVisible(find.text('Use camera on home Wi-Fi'));
    await tester.tap(find.text('Use camera on home Wi-Fi'));
    await settle(tester);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '192.168.1.40');
    await tester.ensureVisible(find.text('Use this camera'));
    await tester.tap(find.text('Use this camera'));
    await settle(tester);
    expect(find.text('Your camera is linked.'), findsNothing);
    expect(camera.closed, isTrue);
    camera.ready = true;
    await tester.ensureVisible(find.text('Use this camera'));
    await tester.tap(find.text('Use this camera'));
    await settle(tester);
    expect(find.text('Your camera is linked.'), findsOneWidget);
    expect(
        container.read(savedCameraProvider).valueOrNull?.host, '192.168.1.40');
    expect(tester.takeException(), isNull);
  });
}
