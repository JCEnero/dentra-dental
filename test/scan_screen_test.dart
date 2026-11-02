import 'dart:async';
import 'dart:typed_data';
import 'package:dentra_mobile/features/scan/data/models/captured_image.dart';
import 'package:dentra_mobile/features/scan/data/scan_regions.dart';
import 'package:dentra_mobile/features/scan/providers/device_connection_provider.dart';
import 'package:dentra_mobile/features/scan/providers/scan_session_provider.dart';
import 'package:dentra_mobile/features/scan/screens/scan_screen.dart';
import 'package:dentra_mobile/features/scan/services/dentra_device_service.dart';
import 'package:dentra_mobile/features/scan/widgets/region_selector.dart';
import 'package:dentra_mobile/features/scan/services/phone_camera_service.dart';
import 'package:dentra_mobile/features/scan/services/screening_analysis_service.dart';
import 'package:dentra_mobile/features/screening/providers/screening_sessions_provider.dart';
import 'package:dentra_mobile/features/screening/data/models/screening_session.dart';
import 'package:dentra_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Fakes: every state change is driven by the test, never a timer ──

CapturedImage _image(CaptureSource source) => CapturedImage(
      bytes: Uint8List.fromList(List.filled(64, 7)),
      source: source,
      capturedAt: DateTime.now(),
    );

class FakeCamera extends PhoneCameraService {
  FakeCamera({this.hasCamera = true});

  final bool hasCamera;
  Completer<CapturedImage?>? pending;
  final List<CaptureSource> calls = [];

  @override
  bool get supportsCamera => hasCamera;

  @override
  Future<CapturedImage?> capture(CaptureSource source) {
    calls.add(source);
    pending = Completer<CapturedImage?>();
    return pending!.future;
  }

  void deliver() => pending!.complete(_image(calls.last));
  void cancel() => pending!.complete(null);
  void fail(CameraFailure f) => pending!.completeError(CameraException(f));
}

class FakeDevice implements DentraDeviceService {
  final StreamController<DeviceLinkEvent> link =
      StreamController<DeviceLinkEvent>.broadcast();
  Completer<void>? connecting;
  Completer<CapturedImage>? capturing;
  ValueChanged<double>? progress;
  int disconnects = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<DeviceLinkEvent> get events => link.stream;

  @override
  Future<void> connect() {
    connecting = Completer<void>();
    return connecting!.future;
  }

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<CapturedImage> capture({ValueChanged<double>? onProgress}) {
    progress = onProgress;
    capturing = Completer<CapturedImage>();
    return capturing!.future;
  }
}

class FakeAnalysis implements ScreeningAnalysisService {
  Completer<ScreeningAnalysisResult>? pending;
  int calls = 0;

  @override
  Future<ScreeningAnalysisResult> analyze(String sessionId) {
    calls++;
    pending = Completer<ScreeningAnalysisResult>();
    return pending!.future;
  }
}

// ── Harness ─────────────────────────────────────────────────────

Future<void> settle(WidgetTester tester, {int steps = 8}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ProviderContainer> pumpScan(
  WidgetTester tester, {
  FakeCamera? camera,
  DentraDeviceService? device,
  ScreeningAnalysisService? analysis,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    phoneCameraServiceProvider.overrideWithValue(camera ?? FakeCamera()),
    if (device != null) dentraDeviceServiceProvider.overrideWithValue(device),
    screeningAnalysisServiceProvider.overrideWithValue(analysis),
  ]);
  addTearDown(container.dispose);

  // Mirrors AppShell: the scan tab sits above the bottom navigation.
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: Column(
            children: [
              const Expanded(child: ScanScreen()),
              AppBottomNav(activeIndex: 1, onTap: (_) {}),
            ],
          ),
        ),
      ),
    ),
  ));
  await settle(tester, steps: 3);
  return container;
}

/// Scrolls the horizontal region list until [label]'s card is built and
/// on screen.
Future<void> showRegion(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    regionCard(label),
    80,
    scrollable: find
        .descendant(
          of: find.byType(RegionSelector),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(regionCard(label));
  await settle(tester, steps: 2);
}

Future<void> tapRegion(WidgetTester tester, String label) async {
  await showRegion(tester, label);
  await tester.tap(regionCard(label), warnIfMissed: false);
  await settle(tester);
}

Finder regionCard(String label) => find.byWidgetPredicate((w) =>
    w is Semantics &&
    (w.properties.label?.startsWith('$label, view') ?? false));

final _progressLabel = find.byWidgetPredicate((w) =>
    w is Semantics &&
    (w.properties.label?.endsWith('views captured') ?? false));

String progressText(WidgetTester tester) =>
    tester.widget<Semantics>(_progressLabel).properties.label!;

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await settle(tester);
}

Future<void> captureCurrent(
    WidgetTester tester, FakeCamera camera, String label) async {
  await tapText(tester, 'Capture $label');
  camera.deliver();
  await settle(tester);
  await tapText(tester, 'Use photo');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('starts honestly: no device, nothing captured, first region',
      (tester) async {
    await pumpScan(tester);

    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    expect(progressText(tester), '0 of 9 views captured');
    for (final r in scanRegions) {
      await showRegion(tester, r.label);
      expect(regionCard(r.label), findsOneWidget);
    }
    expect(find.text('Capture Front Teeth'), findsOneWidget);
    expect(find.text('Opens your phone camera'), findsOneWidget);
    expect(find.text('Start over'), findsNothing);
    // No fabricated quality scores or analysis numbers.
    expect(find.textContaining('Sharpness'), findsNothing);
    expect(find.textContaining('Teeth\ndetected'), findsNothing);
  });

  testWidgets('a second photo is optional and is not another view',
      (tester) async {
    final camera = FakeCamera();
    final container = await pumpScan(tester, camera: camera);
    await captureCurrent(tester, camera, 'Front Teeth');
    await tapRegion(tester, 'Front Teeth');

    await tapText(tester, 'Add another photo');
    await captureCurrent(tester, camera, 'Front Teeth, photo 2');

    expect(progressText(tester), '1 of 9 views captured');
    expect(
      container.read(scanSessionProvider).captures.keys,
      ['front', 'front-2'],
    );
    // Moved on to the next open view, not on to the same view's next photo.
    expect(find.text('Capture Upper Biting Surface'), findsOneWidget);
    await tapRegion(tester, 'Front Teeth');
    expect(find.text('See second photo'), findsOneWidget);
  });

  testWidgets('inner views say they are saved but not checked', (tester) async {
    await pumpScan(tester);
    await tapRegion(tester, 'Back of Upper Teeth');
    expect(find.textContaining("the check can't read"), findsOneWidget);
    await tapRegion(tester, 'Back Molars, Left');
    expect(find.textContaining("the check can't read"), findsNothing);
  });

  test('old screenings keep their own regions, with second photos in place', () {
    expect(regionsForSession(['ul', 'po']), legacyScanRegions);
    expect(scanRegionById('po').label, 'Posterior');
    expect(
      regionsForSession(['front', 'front-2']).take(2).map((r) => r.label),
      ['Front Teeth', 'Front Teeth, photo 2'],
    );
    expect(findScanRegion('nowhere'), isNull);
    expect(
      ScreeningSession(
        id: 's',
        completedAt: DateTime(2026),
        capturedRegions: const ['front', 'front-2'],
        totalRegions: 2,
      ).isComplete,
      isFalse,
    );
  });

  testWidgets('every region renders its own visual and can be selected',
      (tester) async {
    await pumpScan(tester);
    for (final r in scanRegions) {
      await tapRegion(tester, r.label);
      expect(find.text('Capture ${r.label}'), findsOneWidget);
      expect(find.text(r.instruction), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^${r.label}: .*dental arch')),
        findsWidgets,
      );
    }
  });

  testWidgets('a region completes only after a real image is accepted',
      (tester) async {
    final camera = FakeCamera();
    final container = await pumpScan(tester, camera: camera);

    await tapText(tester, 'Capture Front Teeth');
    expect(camera.calls, [CaptureSource.phoneCamera]);
    expect(find.text('Waiting for camera…'), findsWidgets);
    expect(progressText(tester), '0 of 9 views captured');

    // Regions are locked while the camera is open.
    await tapRegion(tester, 'Lower Biting Surface');
    expect(find.text('Front Teeth'), findsWidgets);

    camera.deliver();
    await settle(tester);
    expect(find.text('Check your photo'), findsOneWidget);
    expect(find.text('Use photo'), findsOneWidget);
    expect(progressText(tester), '0 of 9 views captured');

    await tapText(tester, 'Use photo');
    expect(progressText(tester), '1 of 9 views captured');
    expect(find.text('Front Teeth saved'), findsOneWidget);
    // Moves on to the next open region.
    expect(find.text('Capture Upper Biting Surface'), findsOneWidget);
    expect(container.read(scanSessionProvider).captures.keys, ['front']);
    await settle(tester, steps: 30); // notice hides itself
    expect(find.text('Front Teeth saved'), findsNothing);
  });

  testWidgets('cancelling the camera leaves progress unchanged',
      (tester) async {
    final camera = FakeCamera();
    await pumpScan(tester, camera: camera);
    await tapText(tester, 'Capture Front Teeth');
    camera.cancel();
    await settle(tester);
    expect(find.text('Capture Front Teeth'), findsOneWidget);
    expect(find.text('Waiting for camera…'), findsNothing);
    expect(progressText(tester), '0 of 9 views captured');
  });

  testWidgets('permission denied explains, offers retry and a photo',
      (tester) async {
    final camera = FakeCamera();
    await pumpScan(tester, camera: camera);
    await tapText(tester, 'Capture Front Teeth');
    camera.fail(CameraFailure.permissionDenied);
    await settle(tester);

    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.text('Waiting for camera…'), findsNothing);

    await tapText(tester, 'Try again');
    expect(camera.calls.last, CaptureSource.phoneCamera);
    camera.fail(CameraFailure.permissionDenied);
    await settle(tester);

    await tapText(tester, 'Choose a photo');
    expect(camera.calls.last, CaptureSource.photoLibrary);
    camera.deliver();
    await settle(tester);
    expect(find.text('Use photo'), findsOneWidget);
  });

  testWidgets('devices without a camera capture from the photo library',
      (tester) async {
    final camera = FakeCamera(hasCamera: false);
    await pumpScan(tester, camera: camera);
    expect(find.text('Choose Front Teeth photo'), findsOneWidget);
    await tapText(tester, 'Choose Front Teeth photo');
    expect(camera.calls, [CaptureSource.photoLibrary]);
  });

  testWidgets('retake and revisiting keep earlier captures', (tester) async {
    final camera = FakeCamera();
    await pumpScan(tester, camera: camera);

    await tapText(tester, 'Capture Front Teeth');
    camera.deliver();
    await settle(tester);
    await tapText(tester, 'Retake');
    expect(camera.calls, hasLength(2));
    camera.deliver();
    await settle(tester);
    await tapText(tester, 'Use photo');
    await captureCurrent(tester, camera, 'Upper Biting Surface');
    expect(progressText(tester), '2 of 9 views captured');

    // Revisit a captured region: photo shown, progress kept.
    await tapRegion(tester, 'Front Teeth');
    expect(find.text('Your photo'), findsOneWidget);
    expect(find.text('Next: Lower Biting Surface'), findsOneWidget);
    expect(progressText(tester), '2 of 9 views captured');
  });

  testWidgets('partial finish records history without inventing analysis',
      (tester) async {
    final camera = FakeCamera();
    final container = await pumpScan(tester, camera: camera);
    await captureCurrent(tester, camera, 'Front Teeth');

    await tapText(tester, 'Finish with 1 of 9');
    await settle(tester);
    expect(find.text('Partial scan saved'), findsOneWidget);
    expect(find.textContaining("Smart analysis isn't connected"), findsOneWidget);
    expect(find.text('Analyzing images…'), findsNothing);

    final history = await container.read(screeningSessionsProvider.future);
    expect(history, hasLength(1));
    expect(history.single.capturedRegions, ['front']);

    await tapText(tester, 'Start new scan');
    expect(progressText(tester), '0 of 9 views captured');
  });

  testWidgets('analysis state shows only while the request runs; retry works',
      (tester) async {
    final camera = FakeCamera();
    final analysis = FakeAnalysis();
    await pumpScan(tester, camera: camera, analysis: analysis);
    for (final r in scanRegions) {
      await captureCurrent(tester, camera, r.label);
    }
    expect(progressText(tester), '9 of 9 views captured');
    expect(find.text('All 9 views captured'), findsOneWidget);

    await tapText(tester, 'Finish scan');
    expect(analysis.calls, 1);
    expect(find.text('Analyzing images…'), findsOneWidget);

    analysis.pending!
        .completeError(const AnalysisException(AnalysisFailure.offline));
    await settle(tester);
    expect(find.text('Analyzing images…'), findsNothing);
    expect(find.textContaining('offline'), findsOneWidget);

    await tapText(tester, 'Try again');
    expect(analysis.calls, 2);
    expect(find.text('Analyzing images…'), findsOneWidget);
    analysis.pending!.complete(
        const ScreeningAnalysisResult(summary: 'Summary from the service.'));
    await settle(tester);
    expect(find.text('Scan complete'), findsOneWidget);
    expect(find.text('Summary from the service.'), findsOneWidget);
  });

  testWidgets('shows recommendations and photos to retake', (tester) async {
    final camera = FakeCamera();
    final analysis = FakeAnalysis();
    await pumpScan(tester, camera: camera, analysis: analysis);
    await captureCurrent(tester, camera, 'Front Teeth');
    await tapText(tester, 'Finish with 1 of 9');
    analysis.pending!.complete(ScreeningAnalysisResult(
      summary: 'Possible cavity: see a dentist.',
      analysis: ScreeningAnalysis(
        summary: 'Possible cavity: see a dentist.',
        analyzedAt: DateTime(2026, 10, 22),
        recommendations: const [
          ScreeningRecommendation(
            code: 'possible_filling',
            title: 'Possible cavity: see a dentist',
            detail: 'A dentist can check it.',
            urgency: 'soon',
            regionIds: ['front'],
          ),
        ],
        qualityIssues: const [
          ScreeningQualityIssue(
            regionId: 'front',
            modality: 'nir',
            reason: 'blurry',
            message: 'Hold the device still.',
          ),
        ],
      ),
    ));
    await settle(tester);
    expect(find.text('Possible cavity: see a dentist'), findsOneWidget);
    expect(find.text('Book a visit soon'), findsOneWidget);
    expect(find.text('Retake for a better check'), findsOneWidget);
    // No success check while photos still need retaking.
    expect(find.text('Some photos need a retake'), findsOneWidget);
    expect(find.text('Partial scan saved'), findsNothing);
    expect(find.text('Front Teeth (light scan): Hold the device still.'),
        findsOneWidget);
  });

  testWidgets('a backend without analysis finishes without an error',
      (tester) async {
    final camera = FakeCamera();
    final analysis = FakeAnalysis();
    await pumpScan(tester, camera: camera, analysis: analysis);
    await captureCurrent(tester, camera, 'Front Teeth');
    await tapText(tester, 'Finish with 1 of 9');
    analysis.pending!
        .completeError(const AnalysisException(AnalysisFailure.unavailable));
    await settle(tester);
    expect(find.text('Partial scan saved'), findsOneWidget);
    expect(find.textContaining("Smart analysis isn't connected"), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('analysis that never answers times out with recovery',
      (tester) async {
    final camera = FakeCamera();
    final analysis = FakeAnalysis();
    await pumpScan(tester, camera: camera, analysis: analysis);
    await captureCurrent(tester, camera, 'Front Teeth');
    await tapText(tester, 'Finish with 1 of 9');
    expect(find.text('Analyzing images…'), findsOneWidget);

    await tester.pump(ScanSessionNotifier.analysisTimeout + const Duration(seconds: 1));
    await settle(tester);
    expect(find.text('Analyzing images…'), findsNothing);
    expect(find.text('Skip for now'), findsOneWidget);
    await tapText(tester, 'Skip for now');
    expect(find.text('Partial scan saved'), findsOneWidget);
  });

  group('device', () {
    testWidgets('shows connected only after connect succeeds', (tester) async {
      final device = FakeDevice();
      await pumpScan(tester, device: device);
      expect(find.text('Not connected'), findsOneWidget);

      await tapText(tester, 'Connect');
      expect(find.text('Connecting to device…'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);

      device.connecting!.complete();
      await settle(tester);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Uses your DENTRA device'), findsOneWidget);
    });

    testWidgets('slow hint, then a timeout instead of endless loading',
        (tester) async {
      final device = FakeDevice();
      await pumpScan(tester, device: device);
      await tapText(tester, 'Connect');

      await tester.pump(DeviceConnectionNotifier.slowAfter);
      await settle(tester);
      expect(find.textContaining('longer than usual'), findsOneWidget);

      await tester.pump(DeviceConnectionNotifier.connectTimeout);
      await settle(tester);
      expect(find.text('Connection timed out'), findsOneWidget);
      expect(find.text('Connecting to device…'), findsNothing);
      expect(device.disconnects, 1);

      await tapText(tester, 'Try again');
      expect(find.text('Connecting to device…'), findsOneWidget);
      device.connecting!.complete();
      await settle(tester);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('failure messages stay user-friendly', (tester) async {
      final device = FakeDevice();
      await pumpScan(tester, device: device);
      await tapText(tester, 'Connect');
      device.connecting!
          .completeError(const DeviceException(DeviceFailure.notFound));
      await settle(tester);
      expect(find.text('Device not found'), findsOneWidget);
      expect(find.textContaining('DeviceException'), findsNothing);
    });

    testWidgets('device capture shows transfer progress; drops keep progress',
        (tester) async {
      final device = FakeDevice();
      final camera = FakeCamera();
      await pumpScan(tester, device: device, camera: camera);
      await captureCurrent(tester, camera, 'Front Teeth');

      await tapText(tester, 'Connect');
      device.connecting!.complete();
      await settle(tester);

      await tapText(tester, 'Capture Upper Biting Surface');
      expect(camera.calls, hasLength(1)); // device used, not the phone
      device.progress!(0.5);
      await settle(tester);
      expect(find.text('Receiving image… 50%'), findsOneWidget);

      device.capturing!.completeError(
          const DeviceException(DeviceFailure.transferInterrupted));
      await settle(tester);
      expect(find.text('Image transfer interrupted'), findsOneWidget);

      device.link.add(DeviceLinkEvent.reconnecting);
      await settle(tester);
      expect(find.text('Reconnecting…'), findsOneWidget);
      device.link.add(DeviceLinkEvent.disconnected);
      await settle(tester);
      expect(find.text('Connection lost'), findsOneWidget);
      expect(progressText(tester), '1 of 9 views captured');
      // Falls back to the phone camera.
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  testWidgets('start over asks first and keeps work when declined',
      (tester) async {
    final camera = FakeCamera();
    await pumpScan(tester, camera: camera);
    await captureCurrent(tester, camera, 'Front Teeth');

    await tapText(tester, 'Start over');
    expect(find.text('Start over?'), findsOneWidget);
    await tapText(tester, 'Keep scanning');
    expect(progressText(tester), '1 of 9 views captured');

    await tapText(tester, 'Start over');
    await tester.tap(find.text('Start over').last);
    await settle(tester);
    expect(progressText(tester), '0 of 9 views captured');
  });

  for (final (name, size, scale) in [
    ('small phone, large text', const Size(320, 568), 1.3),
    ('standard phone', const Size(390, 844), 1.0),
    ('large phone, accessibility text', const Size(430, 932), 2.0),
  ]) {
    testWidgets('lays out without overflow: $name', (tester) async {
      final camera = FakeCamera();
      await pumpScan(tester, camera: camera, size: size, textScale: scale);
      expect(tester.takeException(), isNull);

      // Main action stays on screen, above the tab bar.
      final action = tester.getRect(find.text('Capture Front Teeth'));
      final nav = tester.getRect(find.byType(AppBottomNav));
      expect(action.bottom, lessThanOrEqualTo(nav.top));
      expect(action.top, greaterThanOrEqualTo(0));

      await tapText(tester, 'Capture Front Teeth');
      camera.deliver();
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Use photo');
      await tapText(tester, 'Finish with 1 of 9');
      expect(tester.takeException(), isNull);
    });
  }
}
