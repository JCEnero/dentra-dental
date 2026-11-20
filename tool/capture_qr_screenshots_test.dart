// ignore_for_file: invalid_use_of_visible_for_testing_member
// Render the production setup screen with demo data; no account/device calls.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dentra_mobile/app/theme.dart';
import 'package:dentra_mobile/features/camera/providers/camera_providers.dart';
import 'package:dentra_mobile/features/camera/screens/qr_setup_screen.dart';
import 'package:dentra_mobile/features/camera/services/setup_sound.dart';
import '../test/camera/qr_setup_fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await settle(tester);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('export real setup screens with demo credentials',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final server = QrTestServer();
    final camera = QrTestCamera();
    final codec = FixedQrCodec();
    final container = ProviderContainer(overrides: [
      camLinkProvider.overrideWithValue(CamLink.cloud),
      cloudCamApiProvider.overrideWithValue(server.api),
      cloudCamClientFactoryProvider.overrideWithValue((_) => camera),
      qrSetupCodecProvider.overrideWithValue(codec),
      setupSoundFactoryProvider.overrideWithValue(QrTestSound.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
            key: const ValueKey('capture'),
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.theme,
                home: Builder(
                    builder: (context) => Scaffold(
                        body: TextButton(
                            onPressed: () => Navigator.of(context)
                                .push(QrSetupScreen.route()),
                            child: const Text('Open'))))))));
    await tap(tester, 'Open');
    Future<void> capture(String name) async {
      for (final scroll
          in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
        if (scroll.position.hasContentDimensions) scroll.position.jumpTo(0);
      }
      await settle(tester);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')));
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('../artifacts/$name.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('qr-setup-prepare');
    await tap(tester, 'My device is on');
    for (final (label, value) in [
      ('Home Wi-Fi name', 'Demo home Wi-Fi'),
      ('Wi-Fi password', 'demo-password')
    ]) {
      final field = find.widgetWithText(TextField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }
    await tap(tester, 'Generate QR');
    await capture('qr-setup-scanning');
    server.state = 'claimed';
    server.online = false;
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    await capture('qr-setup-connecting');
    server.online = true;
    camera.session = codec.last!.session;
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    await capture('qr-setup-connected');
    expect(tester.takeException(), isNull);
  });
}
