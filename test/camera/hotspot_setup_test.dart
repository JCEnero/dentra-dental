import 'dart:convert';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/camera/camera_flow.dart';
import 'package:dentra_mobile/features/camera/camera_strings.dart';
import 'package:dentra_mobile/features/camera/data/saved_camera.dart';
import 'package:dentra_mobile/features/camera/providers/camera_providers.dart';
import 'package:dentra_mobile/features/camera/services/cloud_cam_api.dart';
import 'package:dentra_mobile/features/camera/state/hotspot_setup_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_fakes.dart';

/// The API's camera endpoints, answered by the test.
class FakeCamApi {
  String status = 'pending';
  bool offline = false;
  bool failCreate = false;
  int created = 0;
  int checks = 0;

  static const device = {
    'id': 'cam-1',
    'name': 'Dentra Cam 3F2A',
    'online': true,
    'last_seen_at': '2026-11-11T09:00:00.000Z',
  };

  CloudCamApi get api => CloudCamApi(ApiClient(
        baseUrl: 'https://api.example',
        accessToken: () async => 'user-token',
        client: MockClient(_answer),
      ));

  Future<http.Response> _answer(http.Request req) async {
    if (offline) throw http.ClientException('No internet');
    final path = req.url.path;
    if (req.method == 'POST' && path == '/api/cam/pairings') {
      if (failCreate) {
        return http.Response(
          jsonEncode({
            'error': {'code': 'internal', 'message': 'No'}
          }),
          500,
        );
      }
      created++;
      return http.Response(
        jsonEncode({
          'pairing': {
            'id': 'pairing-$created',
            'code': 'K7P2QX',
            'expires_at': '2026-11-11T09:15:00.000Z',
          },
        }),
        201,
      );
    }
    if (req.method == 'GET' && path.startsWith('/api/cam/pairings/')) {
      checks++;
      return http.Response(
        jsonEncode({
          'pairing': {
            'id': path.split('/').last,
            'status': status,
            'expires_at': '2026-11-11T09:15:00.000Z',
            'device': status == 'claimed' ? device : null,
          },
        }),
        200,
      );
    }
    if (req.method == 'GET' && path == '/api/cam/devices') {
      return http.Response(
          jsonEncode({
            'devices': [device]
          }),
          200);
    }
    return http.Response('{}', 404);
  }
}

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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the guide', () {
    late FakeCamApi server;
    late List<SavedCamera> saved;
    late HotspotSetupController setup;

    void start() {
      server = FakeCamApi();
      saved = [];
      setup = HotspotSetupController(
        api: server.api,
        onSaved: (camera) async => saved.add(camera),
      );
    }

    Future<void> toJoin(WidgetTester tester) async {
      setup
        ..next()
        ..next();
      expect(setup.step, HotspotStep.join);
      expect(setup.codeState, CodeState.loading);
      await tester.pump();
    }

    testWidgets('a code, then the camera using it links it', (tester) async {
      start();
      await toJoin(tester);
      expect(setup.codeState, CodeState.ready);
      expect(setup.pairing!.displayCode, 'K7P 2QX');

      await tester.pump(const Duration(seconds: 2));
      expect(server.checks, 1);
      expect(setup.step, HotspotStep.join, reason: 'still pending');

      server.status = 'claimed';
      await tester.pump(const Duration(seconds: 2));
      expect(setup.step, HotspotStep.ready);
      expect(saved.single.cloudId, 'cam-1');
      expect(saved.single.name, 'Dentra Cam 3F2A');
      expect(saved.single.host, isNull);

      final checks = server.checks;
      await tester.pump(const Duration(seconds: 10));
      expect(server.checks, checks, reason: 'no more checking');
      setup.dispose();
    });

    testWidgets("checks that fail on the camera's Wi-Fi are retried",
        (tester) async {
      start();
      await toJoin(tester);
      server.offline = true;
      await tester.pump(const Duration(seconds: 6));
      expect(setup.step, HotspotStep.join);
      expect(setup.codeState, CodeState.ready);

      server
        ..offline = false
        ..status = 'claimed';
      await tester.pump(const Duration(seconds: 2));
      expect(setup.step, HotspotStep.ready);
      setup.dispose();
    });

    testWidgets('an expired code asks for a new one', (tester) async {
      start();
      await toJoin(tester);
      server.status = 'expired';
      await tester.pump(const Duration(seconds: 2));
      expect(setup.codeState, CodeState.expired);

      server.status = 'pending';
      await setup.newCode();
      expect(setup.codeState, CodeState.ready);
      expect(setup.pairing!.id, 'pairing-2');
      setup.dispose();
    });

    testWidgets("a code that can't be had says so, and can be tried again",
        (tester) async {
      start();
      server.failCreate = true;
      await toJoin(tester);
      expect(setup.codeState, CodeState.failed);
      server.failCreate = false;
      await setup.newCode();
      expect(setup.codeState, CodeState.ready);
      setup.dispose();
    });

    testWidgets('a long wait brings up what usually went wrong',
        (tester) async {
      start();
      await toJoin(tester);
      expect(setup.slow, isFalse);
      await tester.pump(const Duration(minutes: 3));
      expect(setup.slow, isTrue);
      setup.dispose();
    });

    testWidgets('going back stops waiting', (tester) async {
      start();
      await toJoin(tester);
      setup.back();
      expect(setup.step, HotspotStep.power);
      final checks = server.checks;
      await tester.pump(const Duration(seconds: 10));
      expect(server.checks, checks);
      setup.dispose();
    });
  });

  for (final (name, size, scale) in [
    ('small phone, large text', const Size(320, 568), 1.3),
    ('standard phone', const Size(390, 844), 1.0),
    ('large phone, accessibility text', const Size(430, 932), 2.0),
  ]) {
    testWidgets('the website opens its own guide, start to finish: $name',
        (tester) async {
      final server = FakeCamApi();
      final cam = FakeCamClient();
      final container = ProviderContainer(overrides: [
        camLinkProvider.overrideWithValue(CamLink.cloud),
        cloudCamApiProvider.overrideWithValue(server.api),
        cameraClientProvider.overrideWithValue((_) => cam),
      ]);
      addTearDown(container.dispose);
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      SetupOutcome? outcome;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: scale,
            maxScaleFactor: scale,
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async =>
                      outcome = await openCameraSetup(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tapText(tester, 'open');

      // No Bluetooth on this path.
      expect(find.text(CamText.welcomeTitle), findsOneWidget);
      expect(find.text(CamText.permissionTitle), findsNothing);
      expect(tester.takeException(), isNull);

      await tapText(tester, CamText.welcomeStart);
      expect(find.text(CamText.hotspotPowerBody), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapText(tester, CamText.powerReady);
      expect(find.byKey(const ValueKey('pairing-code K7P2QX')), findsOneWidget);
      expect(find.text(CamText.hotspotWaiting), findsOneWidget);
      expect(tester.takeException(), isNull);

      server.status = 'claimed';
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text(CamText.successTitle), findsOneWidget);
      expect(container.read(savedCameraProvider).valueOrNull?.cloudId, 'cam-1');
      // The live picture comes through the camera's own client.
      cam.stream.add(frameBytes(1));
      await settle(tester);
      expect(tester.takeException(), isNull);

      await tapText(tester, CamText.startCapturing);
      expect(outcome, SetupOutcome.startCapturing);
    });
  }
}
