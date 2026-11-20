import 'dart:convert';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/camera/camera_strings.dart';
import 'package:dentra_mobile/features/camera/data/camera_store.dart';
import 'package:dentra_mobile/features/camera/data/saved_camera.dart';
import 'package:dentra_mobile/features/camera/providers/camera_providers.dart';
import 'package:dentra_mobile/features/camera/screens/camera_management_screen.dart';
import 'package:dentra_mobile/features/camera/services/cloud_cam_api.dart';
import 'package:dentra_mobile/shared/widgets/dentra_glass_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Server {
  final devices = [
    {'id': 'cam-1', 'name': 'Dentra Cam FA2C', 'online': false},
    {'id': 'cam-2', 'name': 'Dentra Cam ABCD', 'online': true},
  ];
  final removed = <String>[];
  bool failRemove = false;
  bool failList = false;

  late final api = CloudCamApi(ApiClient(
    baseUrl: 'https://api.example',
    accessToken: () async => 'owner-token',
    client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer owner-token');
      if (request.method == 'DELETE') {
        removed.add(request.url.path.split('/').last);
        if (failRemove) return _error(503, 'unavailable', 'Try again later.');
        devices.removeWhere((camera) => camera['id'] == removed.last);
        return http.Response('', 204);
      }
      if (failList) return _error(503, 'unavailable', 'Try again later.');
      return http.Response(jsonEncode({'devices': devices}), 200);
    }),
  ));
}

http.Response _error(int status, String code, String message) => http.Response(
    jsonEncode({
      'error': {'code': code, 'message': message}
    }),
    status);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump();
  await tester.tap(target);
  await _settle(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (status, code) in [(204, ''), (404, 'not_found')]) {
    test('removal accepts HTTP $status and uses the signed-in owner', () async {
      final api = CloudCamApi(ApiClient(
        baseUrl: 'https://api.example',
        accessToken: () async => 'owner-token',
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/cam/devices/cam-1');
          expect(request.headers['Authorization'], 'Bearer owner-token');
          return status == 204
              ? http.Response('', 204)
              : _error(status, code, 'Already removed.');
        }),
      ));
      await api.removeCamera('cam-1');
    });
  }

  for (final status in [401, 403, 500]) {
    test('a failed removal (HTTP $status) is reported', () async {
      final api = CloudCamApi(ApiClient(
        baseUrl: 'https://api.example',
        accessToken: () async => 'owner-token',
        client: MockClient((_) async => _error(status, 'failed', 'Failed.')),
      ));
      await expectLater(
          api.removeCamera('cam-1'), throwsA(isA<ApiException>()));
    });
  }

  Future<ProviderContainer> open(
    WidgetTester tester,
    _Server server, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 568) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      camLinkProvider.overrideWithValue(CamLink.cloud),
      cloudCamApiProvider.overrideWithValue(server.api),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: const CameraManagementScreen(),
      ),
    ));
    await _settle(tester);
    return container;
  }

  testWidgets(
      'offline camera removal needs confirmation and refreshes selection',
      (tester) async {
    final server = _Server();
    final container = await open(tester, server);
    expect(
        (await container.read(savedCameraProvider.future))!.cloudId, 'cam-1');
    expect(find.text('Dentra Cam FA2C'), findsOneWidget);
    await _tap(tester,
        find.widgetWithText(DentraPillButton, CamText.removeCamera).first);
    expect(server.removed, isEmpty);
    expect(find.text(CamText.removeCameraTitle('Dentra Cam FA2C')),
        findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    expect(server.removed, isEmpty);

    await _tap(tester,
        find.widgetWithText(DentraPillButton, CamText.removeCamera).first);
    await _tap(tester, find.text(CamText.removeCamera).last);
    expect(server.removed, ['cam-1']);
    expect(find.text('Dentra Cam FA2C'), findsNothing);
    expect(find.text('Dentra Cam ABCD'), findsOneWidget);
    expect(
        (await container.read(savedCameraProvider.future))!.cloudId, 'cam-2');

    await _tap(tester,
        find.widgetWithText(DentraPillButton, CamText.removeCamera).first);
    await _tap(tester, find.text(CamText.removeCamera).last);
    expect(find.text(CamText.noCameras), findsOneWidget);
    expect(await container.read(savedCameraProvider.future), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed removal keeps the camera and allows another attempt',
      (tester) async {
    final server = _Server()..failRemove = true;
    final container = await open(tester, server);
    await _tap(tester,
        find.widgetWithText(DentraPillButton, CamText.removeCamera).first);
    await _tap(tester, find.text(CamText.removeCamera).last);
    expect(find.text('Dentra Cam FA2C'), findsOneWidget);
    expect(find.text('Try again later.'), findsOneWidget);
    expect(
        (await container.read(savedCameraProvider.future))!.cloudId, 'cam-1');
    server.failRemove = false;
    await _tap(tester,
        find.widgetWithText(DentraPillButton, CamText.removeCamera).first);
    await _tap(tester, find.text(CamText.removeCamera).last);
    expect(find.text('Dentra Cam FA2C'), findsNothing);
  });

  testWidgets('loading failure can be retried', (tester) async {
    final server = _Server()..failList = true;
    await open(tester, server);
    expect(find.text(CamText.camerasLoadFailed), findsOneWidget);
    server.failList = false;
    await _tap(tester, find.text(CamText.retry));
    expect(find.text('Dentra Cam FA2C'), findsOneWidget);
  });

  testWidgets('small screens and large text keep removal usable',
      (tester) async {
    await open(tester, _Server(), textScale: 2);
    await tester.scrollUntilVisible(find.text('Dentra Cam FA2C'), 200);
    await _tap(tester,
        find.widgetWithText(DentraPillButton, CamText.removeCamera).first);
    expect(find.text(CamText.removeCameraTitle('Dentra Cam FA2C')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('removing a phone camera forgets its saved address', () async {
    const store = CameraStore();
    final camera = SavedCamera(
      host: '192.168.1.8',
      name: 'Dentra Cam FA2C',
      savedAt: DateTime(2026, 11, 15),
    );
    await store.saveCamera(camera);
    final container = ProviderContainer(overrides: [
      camLinkProvider.overrideWithValue(CamLink.local),
    ]);
    addTearDown(container.dispose);
    expect(
        (await container.read(savedCameraProvider.future))!.host, camera.host);
    await container.read(savedCameraProvider.notifier).remove(camera);
    expect(await container.read(savedCameraProvider.future), isNull);
    expect(await store.loadCamera(), isNull);
  });

  test('refreshing or removing another camera keeps the selected camera',
      () async {
    final server = _Server();
    final container = ProviderContainer(overrides: [
      camLinkProvider.overrideWithValue(CamLink.cloud),
      cloudCamApiProvider.overrideWithValue(server.api),
    ]);
    addTearDown(container.dispose);
    final cameras = await container.read(cloudCamerasProvider.future);
    final notifier = container.read(savedCameraProvider.notifier);
    await notifier.save(cameras.last.toSaved());
    expect(
        (await container.read(savedCameraProvider.future))!.cloudId, 'cam-2');
    await notifier.remove(cameras.first.toSaved());
    expect(
        (await container.read(savedCameraProvider.future))!.cloudId, 'cam-2');
  });
}
