// ignore_for_file: invalid_use_of_visible_for_testing_member
// Preview the production guide with the real logo/model and demo account data.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dentra_mobile/app/theme.dart';
import 'package:dentra_mobile/features/camera/camera_flow.dart';
import 'package:dentra_mobile/features/camera/providers/camera_providers.dart';
import 'package:dentra_mobile/features/camera/services/cloud_cam_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/camera/hotspot_setup_test.dart' show FakeCamApi;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('export the minimalist camera connection guide', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
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
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            theme: AppTheme.theme,
            debugShowCheckedModeBanner: false,
            home: Builder(
                builder: (context) => Scaffold(
                        body: TextButton(
                      onPressed: () => openCameraSetup(context),
                      child: const Text('Open'),
                    ))),
          )),
    ));
    await tester.tap(find.text('Open'));
    Future<void> settle() async {
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
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

    await settle();
    await capture('wifi-captive-app-guide');
    expect(
        tester.getBottomLeft(find.text('Setup page didn’t open?')).dy,
        lessThan(
            tester.view.physicalSize.height / tester.view.devicePixelRatio));
    server.status = 'claimed';
    await tester.pump(const Duration(seconds: 2));
    await settle();
    await capture('wifi-captive-app-connected');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
