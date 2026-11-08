import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dentra_mobile/features/scan/data/models/captured_image.dart';
import 'package:dentra_mobile/features/scan/data/scan_outcomes.dart';
import 'package:dentra_mobile/features/scan/data/scan_regions.dart';
import 'package:dentra_mobile/features/scan/data/scan_steps.dart';
import 'package:dentra_mobile/features/scan/providers/device_connection_provider.dart';
import 'package:dentra_mobile/features/scan/providers/scan_session_provider.dart';
import 'package:dentra_mobile/features/scan/screens/scan_screen.dart';
import 'package:dentra_mobile/features/scan/services/dentra_device_service.dart';
import 'package:dentra_mobile/features/scan/widgets/region_selector.dart';
import 'package:dentra_mobile/features/scan/widgets/guide/region_guide_view.dart';
import 'package:dentra_mobile/features/scan/widgets/scan_hero.dart';
import 'package:dentra_mobile/features/scan/services/phone_camera_service.dart';
import 'package:dentra_mobile/features/scan/services/photo_quality.dart';
import 'package:dentra_mobile/features/scan/services/screening_analysis_service.dart';
import 'package:dentra_mobile/features/dental_profile/data/models/dental_answers.dart';
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
  ValueChanged<ScreeningAnalysisProgress>? onProgress;
  int calls = 0;

  @override
  Future<ScreeningAnalysisResult> analyze(
    String sessionId, {
    ValueChanged<ScreeningAnalysisProgress>? onProgress,
  }) {
    calls++;
    this.onProgress = onProgress;
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
  bool pastIntro = true,
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
  if (pastIntro) await startScan(tester);
  return container;
}

/// Taps Start and skips the check-in that opens.
Future<void> startScan(WidgetTester tester) async {
  await tapText(tester, 'Start scan');
  await settle(tester, steps: 5);
  await tapText(tester, 'Skip for now');
  await settle(tester, steps: 5);
}

/// Ends a run the test left waiting, so its timeout timer isn't left pending.
Future<void> endRun(WidgetTester tester, FakeAnalysis analysis) async {
  analysis.pending!
      .completeError(const AnalysisException(AnalysisFailure.offline));
  await settle(tester, steps: 12);
}

/// Runs the 3D scan out once the analysis has answered.
Future<void> finishChamber(WidgetTester tester) async {
  for (var i = 0; i < 400; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Slides the row of views until [label]'s tile is built and on screen.
Future<void> showRegion(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byType(RegionSelector));
  await tester.scrollUntilVisible(
    regionCard(label),
    60,
    scrollable: find
        .descendant(
          of: find.byType(RegionSelector),
          matching: find.byType(Scrollable),
        )
        .first,
  );
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

Future<void> captureCurrent(WidgetTester tester, FakeCamera camera) async {
  await tapText(tester, 'Capture with device');
  camera.deliver();
  await settle(tester);
  await tapText(tester, 'Use photo');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('starts honestly: no device, nothing captured, first region',
      (tester) async {
    await pumpScan(tester, pastIntro: false);

    // A build that can't pair with the device shows no pairing status.
    expect(find.textContaining('DENTRA DEVICE'), findsNothing);
    expect(find.text('Not available yet'), findsNothing);
    expect(find.text('Nine photos,\none screening'), findsOneWidget);
    expect(find.text('Wireless NIR device'), findsOneWidget);
    expect(find.text('Phone camera'), findsNothing);
    expect(find.text('Reaches every side of your teeth'), findsOneWidget);
    expect(find.text('Scanning'), findsNothing);
    for (final step in ['Connect', 'Capture', 'Analyze', 'Act']) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.textContaining('3D'), findsNothing);
    await startScan(tester);

    expect(progressText(tester), '0 of 9 views captured');
    for (final r in scanRegions) {
      await showRegion(tester, r.label);
      expect(regionCard(r.label), findsOneWidget);
    }
    expect(find.text('Capture with device'), findsOneWidget);
    expect(find.text('What your device should see'), findsOneWidget);
    expect(find.text('Start over'), findsNothing);
    // No fabricated quality scores or analysis numbers.
    expect(find.textContaining('Sharpness'), findsNothing);
    expect(find.textContaining('Teeth\ndetected'), findsNothing);
  });

  testWidgets('a second photo is optional and is not another view',
      (tester) async {
    final camera = FakeCamera();
    final container = await pumpScan(tester, camera: camera);
    await captureCurrent(tester, camera);
    await tapRegion(tester, 'Front Teeth');

    await tapText(tester, 'Add another photo');
    await captureCurrent(tester, camera);

    expect(progressText(tester), '1 of 9 views captured');
    expect(
      container.read(scanSessionProvider).captures.keys,
      ['front', 'front-2'],
    );
    // Moved on to the next open view, not on to the same view's next photo.
    expect(find.text('Upper Biting Surface'), findsOneWidget);
    await tapRegion(tester, 'Front Teeth');
    expect(find.text('See second photo'), findsOneWidget);
  });

  testWidgets('inner views show no note while capturing', (tester) async {
    await pumpScan(tester);
    await tapRegion(tester, 'Back of Upper Teeth');
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
      expect(find.text(r.label), findsWidgets);
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

    await tapText(tester, 'Capture with device');
    expect(camera.calls, [CaptureSource.phoneCamera]);
    expect(find.text('Waiting for device…'), findsWidgets);
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
    // Moves on to the next open region.
    expect(find.text('Upper Biting Surface'), findsOneWidget);
    expect(container.read(scanSessionProvider).captures.keys, ['front']);
  });

  testWidgets('cancelling the camera leaves progress unchanged',
      (tester) async {
    final camera = FakeCamera();
    await pumpScan(tester, camera: camera);
    await tapText(tester, 'Capture with device');
    camera.cancel();
    await settle(tester);
    expect(find.text('Capture with device'), findsOneWidget);
    expect(find.text('Waiting for device…'), findsNothing);
    expect(progressText(tester), '0 of 9 views captured');
  });

  testWidgets('permission denied explains, offers retry and a photo',
      (tester) async {
    final camera = FakeCamera();
    await pumpScan(tester, camera: camera);
    await tapText(tester, 'Capture with device');
    camera.fail(CameraFailure.permissionDenied);
    await settle(tester);

    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.text('Waiting for device…'), findsNothing);

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
    expect(find.text('Choose a photo'), findsOneWidget);
    await tapText(tester, 'Choose a photo');
    expect(camera.calls, [CaptureSource.photoLibrary]);
  });

  testWidgets('retake and revisiting keep earlier captures', (tester) async {
    final camera = FakeCamera();
    await pumpScan(tester, camera: camera);

    await tapText(tester, 'Capture with device');
    camera.deliver();
    await settle(tester);
    await tapText(tester, 'Retake');
    expect(camera.calls, hasLength(2));
    camera.deliver();
    await settle(tester);
    await tapText(tester, 'Use photo');
    await captureCurrent(tester, camera);
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
    await captureCurrent(tester, camera);

    await tapText(tester, 'Finish with 1 of 9');
    await settle(tester);
    expect(find.text('Partial scan saved'), findsOneWidget);
    expect(find.textContaining("Smart analysis isn't connected"), findsOneWidget);
    expect(find.text('Analyzing images…'), findsNothing);

    final history = await container.read(screeningSessionsProvider.future);
    expect(history, hasLength(1));
    expect(history.single.capturedRegions, ['front']);

    await tapText(tester, 'Start new scan');
    expect(find.text('Start scan'), findsOneWidget);
    await startScan(tester);
    expect(progressText(tester), '0 of 9 views captured');
  });

  testWidgets('analysis state shows only while the request runs; retry works',
      (tester) async {
    final camera = FakeCamera();
    final analysis = FakeAnalysis();
    await pumpScan(tester, camera: camera, analysis: analysis);
    for (var i = 0; i < scanRegions.length; i++) {
      await captureCurrent(tester, camera);
    }
    expect(progressText(tester), '9 of 9 views captured');

    await tapText(tester, 'Finish scan');
    await settle(tester);
    expect(analysis.calls, 1);
    expect(find.text('Scanning your teeth'), findsOneWidget);

    analysis.pending!
        .completeError(const AnalysisException(AnalysisFailure.offline));
    await settle(tester, steps: 12);
    expect(find.text('Scanning your teeth'), findsNothing);
    expect(find.textContaining('offline'), findsOneWidget);

    await tapText(tester, 'Try again');
    await settle(tester);
    expect(analysis.calls, 2);
    expect(find.text('Scanning your teeth'), findsOneWidget);
    analysis.pending!.complete(
        const ScreeningAnalysisResult(summary: 'Summary from the service.'));
    await finishChamber(tester);
    expect(find.text('Scan complete'), findsOneWidget);
    expect(find.text('Summary from the service.'), findsOneWidget);
  });

  testWidgets('shows recommendations and photos to retake', (tester) async {
    final camera = FakeCamera();
    final analysis = FakeAnalysis();
    await pumpScan(tester, camera: camera, analysis: analysis);
    await captureCurrent(tester, camera);
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
    await finishChamber(tester);
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
    await captureCurrent(tester, camera);
    await tapText(tester, 'Finish with 1 of 9');
    analysis.pending!
        .completeError(const AnalysisException(AnalysisFailure.unavailable));
    await settle(tester, steps: 12);
    expect(find.text('Partial scan saved'), findsOneWidget);
    expect(find.textContaining("Smart analysis isn't connected"), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('analysis that never answers times out with recovery',
      (tester) async {
    final camera = FakeCamera();
    final analysis = FakeAnalysis();
    await pumpScan(tester, camera: camera, analysis: analysis);
    await captureCurrent(tester, camera);
    await tapText(tester, 'Finish with 1 of 9');
    await settle(tester);
    expect(find.text('Scanning your teeth'), findsOneWidget);

    await tester.pump(ScanSessionNotifier.analysisTimeout + const Duration(seconds: 1));
    await settle(tester, steps: 12);
    expect(find.text('Scanning your teeth'), findsNothing);
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
      expect(find.text('Capture with device'), findsOneWidget);
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
      await captureCurrent(tester, camera);

      await tapText(tester, 'Connect');
      device.connecting!.complete();
      await settle(tester);

      await tapText(tester, 'Capture with device');
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

  group('the check-in before a scan', () {
    testWidgets('closing it stays on the start page', (tester) async {
      await pumpScan(tester, pastIntro: false);
      await tapText(tester, 'Start scan');
      await settle(tester, steps: 5);
      expect(find.text('Before you scan'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await settle(tester, steps: 8);
      expect(find.text('Before you scan'), findsNothing);
      expect(find.text('Start scan'), findsOneWidget);
    });

    testWidgets('skipping it starts the scan with nothing stored',
        (tester) async {
      final container = await pumpScan(tester, pastIntro: false);
      await startScan(tester);
      expect(progressText(tester), '0 of 9 views captured');
      expect(container.read(scanSessionProvider).checkIn, isNull);
    });

    testWidgets('isn\'t asked again on the way back to the start page',
        (tester) async {
      final container = await pumpScan(tester, pastIntro: false);
      await startScan(tester);
      container.read(scanSessionProvider.notifier).showIntro();
      await settle(tester);
      await tapText(tester, 'Start scan');
      await settle(tester, steps: 5);
      expect(find.text('Before you scan'), findsNothing);
      expect(progressText(tester), '0 of 9 views captured');
    });

    testWidgets('what\'s said goes with the scan, and survives a retake',
        (tester) async {
      final camera = FakeCamera();
      final analysis = FakeAnalysis();
      final container = await pumpScan(
        tester,
        camera: camera,
        analysis: analysis,
        pastIntro: false,
      );
      await tapText(tester, 'Start scan');
      await settle(tester, steps: 5);
      await tapText(tester, 'Tooth pain');
      // One question at a time: on through the rest, then Continue.
      for (var i = 0; i < 12 && find.text('Continue').evaluate().isEmpty; i++) {
        await tapText(tester, 'Next');
      }
      await tapText(tester, 'Continue');
      await settle(tester, steps: 5);
      final said = container.read(scanSessionProvider).checkIn;
      expect(said?.symptoms, {CurrentConcern.toothPain});

      await captureCurrent(tester, camera);
      await tapText(tester, 'Finish with 1 of 9');
      await settle(tester, steps: 12);
      final history = await container.read(screeningSessionsProvider.future);
      expect(history.first.checkIn?.symptoms, {CurrentConcern.toothPain});
      await endRun(tester, analysis);
    });
  });

  testWidgets('start over asks first and keeps work when declined',
      (tester) async {
    final camera = FakeCamera();
    await pumpScan(tester, camera: camera);
    await captureCurrent(tester, camera);

    await tapText(tester, 'Start over');
    expect(find.text('Start over?'), findsOneWidget);
    await tapText(tester, 'Keep scanning');
    expect(progressText(tester), '1 of 9 views captured');

    await tapText(tester, 'Start over');
    await tester.tap(find.text('Start over').last);
    await settle(tester);
    expect(find.text('Start scan'), findsOneWidget);
    await startScan(tester);
    expect(progressText(tester), '0 of 9 views captured');
  });

  for (final (name, size, scale) in [
    ('small phone, large text', const Size(320, 568), 1.3),
    ('standard phone', const Size(390, 844), 1.0),
    ('large phone, accessibility text', const Size(430, 932), 2.0),
  ]) {
    testWidgets('the start page lays out without overflow: $name',
        (tester) async {
      await pumpScan(tester, pastIntro: false, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      // A whole loop of the scan going round the teeth.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow: $name', (tester) async {
      final camera = FakeCamera();
      await pumpScan(tester, camera: camera, size: size, textScale: scale);
      expect(tester.takeException(), isNull);

      // Main action stays on screen, above the tab bar.
      final action = tester.getRect(find.text('Capture with device'));
      final nav = tester.getRect(find.byType(AppBottomNav));
      expect(action.bottom, lessThanOrEqualTo(nav.top));
      expect(action.top, greaterThanOrEqualTo(0));

      await tapText(tester, 'Capture with device');
      camera.deliver();
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Use photo');
      await tapText(tester, 'Finish with 1 of 9');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the 3D scan lays out without overflow: $name', (tester) async {
      final camera = FakeCamera();
      final analysis = FakeAnalysis();
      await pumpScan(tester,
          camera: camera,
          analysis: analysis,
          size: size,
          textScale: scale);
      await captureCurrent(tester, camera);
      await tapText(tester, 'Finish with 1 of 9');
      await settle(tester, steps: 12);
      expect(find.text('Scanning your teeth'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await endRun(tester, analysis);
    });
  }

  group('the start page', () {
    test('the device takes nine photos, one at a time, then starts over', () {
      expect(HeroStory.taken(0), 0);
      expect(HeroStory.filled(0, 0), 0);
      expect(HeroStory.flash(0), 0);

      expect(HeroStory.taken(HeroStory.complete), HeroStory.photos);
      for (var i = 0; i < HeroStory.photos; i++) {
        expect(HeroStory.flash(HeroStory.takenAt(i)), 1);
        expect(HeroStory.filled(i, HeroStory.restful), 1);
        expect(HeroStory.filled(i, HeroStory.loop), 0);
      }
    });

    testWidgets('shows the device, not the teeth model, for a whole loop',
        (tester) async {
      await pumpScan(tester, pastIntro: false);
      expect(find.byType(ScanHero), findsOneWidget);
      expect(find.byType(RegionGuideView), findsNothing);
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('holds still under reduced motion', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ScanHero(height: 226)),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('the 3D scan follows the real run', () {
    Future<(ProviderContainer, FakeAnalysis)> startRun(
      WidgetTester tester, {
      int photos = 2,
    }) async {
      final camera = FakeCamera();
      final analysis = FakeAnalysis();
      final container =
          await pumpScan(tester, camera: camera, analysis: analysis);
      for (var i = 0; i < photos; i++) {
        await captureCurrent(tester, camera);
      }
      await tapText(tester, 'Finish with $photos of 9');
      // Past the opening, to where the first photo waits to be read.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return (container, analysis);
    }

    ScreeningAnalysisResult answer() => ScreeningAnalysisResult(
          summary: 'All done.',
          analysis: ScreeningAnalysis(
            summary: 'All done.',
            analyzedAt: DateTime(2026, 11, 2),
          ),
        );

    testWidgets('a photo only counts once the server has finished it',
        (tester) async {
      final (_, analysis) = await startRun(tester);
      expect(find.text('0 of 2 read'), findsOneWidget);

      // However long the server takes, nothing moves on by itself.
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('0 of 2 read'), findsOneWidget);

      analysis.onProgress!(const ScreeningAnalysisProgress(done: 1, total: 2));
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('1 of 2 read'), findsOneWidget);
      await endRun(tester, analysis);
    });

    testWidgets('it explains each step, in order, in everyday words',
        (tester) async {
      final (_, analysis) = await startRun(tester);
      analysis.onProgress!(const ScreeningAnalysisProgress(done: 2, total: 2));
      final seen = <String>[];
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        for (final step in readingSteps) {
          if (find.text(step.title).evaluate().isNotEmpty &&
              !seen.contains(step.title)) {
            seen.add(step.title);
          }
        }
      }
      expect(seen, [for (final step in readingSteps) step.title]);
      await endRun(tester, analysis);
    });

    test('no step uses the word AI or leaves a sentence out', () {
      expect(allScanSteps, hasLength(10));
      for (final step in allScanSteps) {
        expect(step.title, isNot(contains('AI')));
        expect(step.body, isNot(matches(RegExp(r'\bAI\b'))));
        expect(step.body.split(RegExp(r'[.!?]\s')).length, greaterThan(1));
      }
    });

    testWidgets('results only show once the analysis has really answered',
        (tester) async {
      final (_, analysis) = await startRun(tester);
      analysis.onProgress!(const ScreeningAnalysisProgress(done: 2, total: 2));
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Every photo read, but no answer yet: still waiting, nothing invented.
      expect(find.text('Scanning your teeth'), findsOneWidget);
      expect(find.text(resultSteps.last.title), findsNothing);

      analysis.pending!.complete(answer());
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(resultSteps.last.title), findsOneWidget);
      await finishChamber(tester);
      expect(find.text('Scanning your teeth'), findsNothing);
      expect(find.text('Nothing flagged in your photos'), findsOneWidget);
    });

    testWidgets('closing the scan leaves the run going behind the page',
        (tester) async {
      final (container, analysis) = await startRun(tester, photos: 1);
      await tester.tap(find.byTooltip('Keep going in the background'));
      await settle(tester, steps: 12);
      expect(find.text('Scanning your teeth'), findsNothing);
      expect(find.text('Analyzing images…'), findsOneWidget);

      analysis.pending!.complete(answer());
      await settle(tester, steps: 12);
      expect(find.text('Nothing flagged in your photos'), findsOneWidget);
      expect(container.read(scanSessionProvider).finishPhase, FinishPhase.done);
    });
  });

  group('retaking flagged photos', () {
    ScreeningAnalysisResult flagged(String regionId) => ScreeningAnalysisResult(
          summary: 'Almost.',
          analysis: ScreeningAnalysis(
            summary: 'Almost.',
            analyzedAt: DateTime(2026, 11, 2),
            qualityIssues: [
              ScreeningQualityIssue(
                regionId: regionId,
                modality: 'rgb',
                reason: 'no_teeth',
                message: 'No teeth detected.',
              ),
            ],
          ),
        );

    testWidgets('keeps the good photos and updates the same screening',
        (tester) async {
      final camera = FakeCamera();
      final analysis = FakeAnalysis();
      final container =
          await pumpScan(tester, camera: camera, analysis: analysis);
      await captureCurrent(tester, camera);
      await captureCurrent(tester, camera);
      await tapText(tester, 'Finish with 2 of 9');
      analysis.pending!.complete(flagged('upper-occlusal'));
      await finishChamber(tester);

      expect(find.text('Some photos need a retake'), findsOneWidget);
      await tapText(tester, 'Retake 1 photo');
      expect(progressText(tester), '1 of 9 views captured');
      expect(find.text('Upper Biting Surface'), findsOneWidget);
      expect(container.read(scanSessionProvider).captures.keys, ['front']);

      await captureCurrent(tester, camera);
      await tapText(tester, 'Finish with 2 of 9');
      await settle(tester);
      expect(analysis.calls, 2);
      analysis.pending!.complete(const ScreeningAnalysisResult(summary: 'Good.'));
      await finishChamber(tester);

      final history = await container.read(screeningSessionsProvider.future);
      expect(history, hasLength(1));
      expect(history.single.capturedRegions, ['front', 'upper-occlusal']);
    });
  });

  group('what the analysis said', () {
    ScreeningAnalysis analysis({
      List<ScreeningFinding> findings = const [],
      List<ScreeningRecommendation> notes = const [],
      List<ScreeningQualityIssue> issues = const [],
    }) =>
        ScreeningAnalysis(
          summary: 's',
          analyzedAt: DateTime(2026),
          findings: findings,
          recommendations: notes,
          qualityIssues: issues,
        );

    test('each photo gets its own outcome', () {
      final out = outcomesOf(
        analysis(
          findings: const [
            ScreeningFinding(label: 'Possible tooth decay', regionId: 'left'),
          ],
          notes: const [
            ScreeningRecommendation(
              code: 'possible_filling',
              title: 't',
              detail: 'd',
              urgency: 'soon',
              regionIds: ['left'],
            ),
          ],
          issues: const [
            ScreeningQualityIssue(
              regionId: 'right',
              modality: 'rgb',
              reason: 'no_teeth',
              message: 'm',
            ),
            // A light-scan frame's problem doesn't flag the photo.
            ScreeningQualityIssue(
              regionId: 'front',
              modality: 'nir',
              reason: 'blurry',
              message: 'm',
            ),
          ],
        ),
        ['front', 'left', 'left-2', 'right', 'upper-lingual'],
      );
      expect(out, {
        'front': ViewOutcome.clear,
        'left': ViewOutcome.urgent,
        // The second photo of a view keeps its own result.
        'left-2': ViewOutcome.clear,
        'right': ViewOutcome.retake,
        'upper-lingual': ViewOutcome.notChecked,
      });
    });

    test('a note about braces is not a finding', () {
      final out = outcomesOf(
        analysis(notes: const [
          ScreeningRecommendation(
            code: 'braces_seen',
            title: 't',
            detail: 'd',
            urgency: 'routine',
            regionIds: ['front'],
          ),
        ]),
        ['front'],
      );
      expect(out['front'], ViewOutcome.clear);
    });

    test('an area takes the most any photo of it said, and only its own', () {
      const outcomes = {
        'left': ViewOutcome.finding,
        'upper-occlusal': ViewOutcome.clear,
      };
      expect(areaOutcome(MouthArea.upperLeft, outcomes), ViewOutcome.finding);
      expect(areaOutcome(MouthArea.upperRight, outcomes), ViewOutcome.clear);
      // A side photo reaches one canine, but says nothing about the front.
      expect(areaOutcome(MouthArea.lowerFront, outcomes), isNull);
    });
  });

  group('measuring a photo on the device', () {
    Future<Uint8List> png(int width, int height) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xFF888888), BlendMode.src);
      final image =
          await recorder.endRecording().toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }

    testWidgets('a photo too small to read is called out before it is sent',
        (tester) async {
      await tester.runAsync(() async {
        Future<bool?> tooSmall(int w, int h) async =>
            (await PhotoQuality.measure(await png(w, h)))?.tooSmall;
        expect(await tooSmall(225, 225), isTrue);
        expect(await tooSmall(200, 800), isTrue);
        expect(await tooSmall(600, 200), isTrue);
        expect(await tooSmall(240, 240), isFalse);
        expect(await tooSmall(1920, 1080), isFalse);
        // Wide enough to be scaled down thin, but really tall enough.
        expect(await tooSmall(2600, 300), isFalse);
      });
    });


    Uint8List pixels(int w, int h, int Function(int x, int y) gray) {
      final out = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final v = gray(x, y);
          final i = (y * w + x) * 4;
          out[i] = out[i + 1] = out[i + 2] = v;
          out[i + 3] = 255;
        }
      }
      return out;
    }

    int checker(int x, int y) => (x + y).isEven ? 90 : 160;

    test('a well-lit, detailed photo passes', () {
      final q = PhotoQuality.fromRgba(pixels(64, 48, checker), 64, 48);
      expect(q.light, PhotoLight.good);
      expect(q.focus, PhotoFocus.sharp);
    });

    test('dark, glaring and flat photos are called out', () {
      expect(
        PhotoQuality.fromRgba(pixels(64, 48, (x, y) => 10), 64, 48).light,
        PhotoLight.dark,
      );
      expect(
        PhotoQuality.fromRgba(pixels(64, 48, (x, y) => 255), 64, 48).light,
        PhotoLight.glare,
      );
      expect(
        PhotoQuality.fromRgba(pixels(64, 48, (x, y) => 120), 64, 48).focus,
        PhotoFocus.soft,
      );
    });
  });
}
