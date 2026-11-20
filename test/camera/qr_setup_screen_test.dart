import 'package:dentra_mobile/features/camera/camera_flow.dart';
import 'package:dentra_mobile/features/camera/providers/camera_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dentra_mobile/features/camera/screens/qr_setup_screen.dart';
import 'package:dentra_mobile/features/camera/screens/device_sticker_scan_screen.dart';
import 'package:dentra_mobile/features/camera/widgets/qr_scan_scene.dart';
import 'package:dentra_mobile/features/camera/services/setup_sound.dart';
import 'package:dentra_mobile/shared/widgets/dentra_mascot.dart';
import 'package:dentra_mobile/shared/widgets/mascot_stage.dart';
import 'package:dentra_mobile/features/camera/widgets/qr_setup_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'qr_setup_fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; ++i) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await settle(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final (size, scale, platform) in [
    (const Size(320, 568), 1.3, TargetPlatform.android),
    (const Size(390, 844), 1.0, TargetPlatform.iOS),
    (const Size(430, 932), 2.0, TargetPlatform.android),
  ]) {
    testWidgets('shared optical setup $size, text $scale, $platform',
        (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final server = QrTestServer();
      final camera = QrTestCamera();
      final codec = FixedQrCodec();
      final sounds = QrTestSound();
      final container = ProviderContainer(overrides: [
        camLinkProvider.overrideWithValue(CamLink.cloud),
        cloudCamApiProvider.overrideWithValue(server.api),
        cloudCamClientFactoryProvider.overrideWithValue((_) => camera),
        qrSetupCodecProvider.overrideWithValue(codec),
        setupSoundFactoryProvider.overrideWithValue(() => sounds),
        deviceStickerScannerProvider.overrideWithValue((_) async =>
            throw StateError('Simple setup must never open the phone scanner')),
      ]);
      addTearDown(container.dispose);
      SetupOutcome? result;
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                  minScaleFactor: scale, maxScaleFactor: scale, child: child!),
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () async => result =
                              await Navigator.of(context)
                                  .push(QrSetupScreen.route()),
                          child: const Text('Open')))))));
      await tap(tester, 'Open');
      await tap(tester, 'My device is on');
      expect(find.textContaining('192.168.4.1'), findsNothing);
      expect(find.widgetWithText(TextField, 'QR setup key'), findsNothing);
      expect(find.text('Scan device sticker'), findsNothing);
      expect(find.text('Enter key manually'), findsNothing);
      for (final (label, value) in [
        ('Home Wi-Fi name', 'Home'),
        ('Wi-Fi password', 'correct horse'),
      ]) {
        final field = find.widgetWithText(TextField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }
      await tap(tester, 'Generate QR');
      expect(find.byKey(const ValueKey('setup-qr')), findsOneWidget);
      expect(find.byType(CompactSetupQr), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('setup-qr'))).width,
          lessThanOrEqualTo(220));
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
      expect(tester.widget<MascotSpot>(find.byType(MascotSpot).last).mood,
          MascotMood.point);
      expect(sounds.plays, 2);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(sounds.plays, 2); // Polling does not replay the poof.
      await tap(tester, 'Enlarge code');
      expect(find.byKey(const ValueKey('expanded-setup-qr')), findsOneWidget);
      Navigator.of(
              tester.element(find.byKey(const ValueKey('expanded-setup-qr'))))
          .pop();
      await settle(tester);
      expect(server.creates, 1);
      final mute = find.byTooltip('Mute mascot sounds');
      await tester.ensureVisible(mute);
      await tester.tap(mute);
      await settle(tester);
      expect(sounds.stops, 1);
      expect(find.textContaining('QR detected.'), findsNothing);
      expect(
          tester
              .widget<QrScanScene>(
                  find.byKey(const ValueKey('qr-device-model')))
              .confirmed,
          false);
      camera.session = codec.last!.session;
      expect(codec.last!.data, startsWith('DENTRA2:'));
      expect(codec.last!.data, contains('correct horse'));
      expect(find.widgetWithText(TextField, 'Wi-Fi password'), findsNothing);
      expect(tester.takeException(), isNull);
      server.state = 'claimed';
      server.online = false;
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('Device found · connecting'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-qr')), findsOneWidget);
      expect(find.textContaining('QR detected.'), findsNothing);
      expect(tester.widget<MascotSpot>(find.byType(MascotSpot).last).mood,
          MascotMood.think);
      expect(sounds.plays, 2);
      final enable = find.byTooltip('Enable mascot sounds');
      await tester.ensureVisible(enable);
      await tester.tap(enable);
      await settle(tester);
      expect(sounds.plays, 3);
      server.online = true;
      camera.ready = false;
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('QR confirmed · checking camera'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-qr')), findsNothing);
      expect(find.text('You’re all\nconnected.'), findsNothing);
      expect(
          tester
              .widget<QrScanScene>(
                  find.byKey(const ValueKey('qr-device-model')))
              .confirmed,
          true);
      expect(tester.widget<MascotSpot>(find.byType(MascotSpot).last).mood,
          MascotMood.watch);
      camera.ready = true;
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('You’re all\nconnected.'), findsOneWidget);
      expect(
          tester
              .widget<QrScanScene>(
                  find.byKey(const ValueKey('qr-device-model')))
              .connected,
          true);
      expect(tester.widget<MascotSpot>(find.byType(MascotSpot).last).mood,
          MascotMood.cheer);
      expect(
          container.read(savedCameraProvider).valueOrNull?.cloudId, 'cloud-1');
      expect(tester.takeException(), isNull);
      await tap(tester, 'Done');
      expect(result, SetupOutcome.done);
      expect(sounds.closed, true);
      expect(sounds.plays, 5);
    });
  }
}
