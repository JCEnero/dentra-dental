import 'package:dentra_mobile/features/camera/camera_flow.dart'
    show SetupOutcome;
import 'package:dentra_mobile/features/camera/providers/camera_providers.dart';
import 'package:dentra_mobile/features/camera/screens/wifi_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wifi_setup_fakes.dart';
import 'package:dentra_mobile/features/camera/services/cloud_cam_api.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await settle(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (size, scale) in [
    (const Size(320, 568), 1.3),
    (const Size(390, 844), 1.0),
    (const Size(430, 932), 2.0),
  ]) {
    for (final browser in [false, true]) {
      testWidgets(
          '${browser ? 'browser' : 'mobile'} in-app setup completes without overflow at $size, text $scale',
          (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final transport = FakeProvisioning()..browser = browser;
        final container = ProviderContainer(overrides: [
          camLinkProvider
              .overrideWithValue(browser ? CamLink.cloud : CamLink.local),
          if (browser)
            cloudCamerasProvider
                .overrideWith((ref) async => transport.state == 'connected'
                    ? [
                        const CloudCamera(
                            id: 'cam-1', name: 'Dentra Cam 3F2A', online: true),
                      ]
                    : []),
          wifiProvisioningProvider.overrideWithValue(() => transport),
        ]);
        addTearDown(container.dispose);
        SetupOutcome? outcome;
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                  minScaleFactor: scale, maxScaleFactor: scale, child: child!),
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () async => outcome =
                              await Navigator.of(context)
                                  .push(WifiSetupScreen.route()),
                          child: const Text('Open setup'))))),
        ));
        await tap(tester, 'Open setup');
        expect(find.text('1 of 4'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, 'My device is on');
        if (!browser) {
          await tester.ensureVisible(find.byType(TextField));
          await tester.enterText(find.byType(TextField), '0123456789ABCDEF');
        } else {
          expect(find.textContaining('192.168.4.1'), findsNothing);
          expect(find.byType(TextField), findsNothing);
        }
        await tap(
            tester, browser ? 'I’ve joined Dentra Wi-Fi' : 'Connect to device');
        expect(find.text('Available networks'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, 'Home');
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'correct horse');
        await settle(tester);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.obscureText, isTrue);
        await tester.ensureVisible(find.byTooltip('Show password'));
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();
        expect(tester.widget<TextField>(find.byType(TextField)).obscureText,
            isFalse);
        await tap(tester, 'Connect to home Wi-Fi');
        expect(find.text('You’re all\nconnected.'), findsOneWidget);
        final saved = container.read(savedCameraProvider).valueOrNull;
        expect(browser ? saved?.cloudId : saved?.host,
            browser ? 'cam-1' : '192.168.1.40');
        expect(tester.takeException(), isNull);
        await tap(tester, 'Continue');
        expect(outcome, SetupOutcome.done);
        expect(transport.closed, isTrue);
      });
    }
  }

  testWidgets(
      'a hidden open network keeps its exact SSID and sends no password',
      (tester) async {
    final transport = FakeProvisioning();
    final container = ProviderContainer(overrides: [
      camLinkProvider.overrideWithValue(CamLink.local),
      wifiProvisioningProvider.overrideWithValue(() => transport),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WifiSetupScreen())));
    await settle(tester);
    await tap(tester, 'My device is on');
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '0123456789ABCDEF');
    await tap(tester, 'Connect to device');
    await tap(tester, 'My network is hidden');
    await tap(tester, 'Use this network');
    expect(find.text('Enter a network name of 1–32 bytes.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Clinic Wi-Fi  ');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tap(tester, 'Use this network');
    expect(
        find.text('This network doesn’t require a password.'), findsOneWidget);
    await tap(tester, 'Connect to home Wi-Fi');
    expect(transport.posts.first.$2['ssid'], '  Clinic Wi-Fi  ');
    expect(transport.posts.first.$2['password'], '');
    expect(find.text('You’re all\nconnected.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an invalid setup key leaves a usable retry and close action',
      (tester) async {
    final transport = FakeProvisioning();
    final container = ProviderContainer(overrides: [
      wifiProvisioningProvider.overrideWithValue(() => transport)
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WifiSetupScreen())));
    await settle(tester);
    await tap(tester, 'My device is on');
    await tap(tester, 'Connect to device');
    expect(find.text('Enter the 16-character setup key on your device label.'),
        findsOneWidget);
    expect(find.text('Connect to device'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
