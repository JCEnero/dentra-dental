// ignore_for_file: invalid_use_of_visible_for_testing_member
// Render the legacy in-app Wi-Fi setup with demo data; no device/account calls.
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
import 'package:dentra_mobile/features/camera/screens/wifi_setup_screen.dart';
import '../test/camera/wifi_setup_fakes.dart';

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
  testWidgets('export in-app Wi-Fi glass screens with demo data',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final device = FakeProvisioning();
    final container = ProviderContainer(overrides: [
      camLinkProvider.overrideWithValue(CamLink.local),
      wifiProvisioningProvider.overrideWithValue(() => device),
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
                                .push(WifiSetupScreen.route()),
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

    await capture('wifi-setup-prepare');
    await tap(tester, 'My device is on');
    await capture('wifi-setup-device');
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '0123456789ABCDEF');
    await tap(tester, 'Connect to device');
    await capture('wifi-setup-networks');
    await tap(tester, 'Home');
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'demo-password');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await capture('wifi-setup-password');
    await tap(tester, 'Connect to home Wi-Fi');
    await capture('wifi-setup-connected');
    expect(tester.takeException(), isNull);
  });
}
