import 'dart:async';

import 'package:dentra_mobile/features/camera/screens/device_sticker_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_setup_fakes.dart';

class TestScanner extends MobileScannerPlatform {
  final frames = StreamController<BarcodeCapture>.broadcast();
  int starts = 0;
  int stops = 0;
  bool disposed = false;
  bool denied = false;
  @override
  Stream<BarcodeCapture?> get barcodesStream => frames.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    expect(options.cameraDirection, CameraFacing.back);
    expect(options.returnImage, false);
    if (denied) {
      throw const MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied);
    }
    return const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(400, 400),
        numberOfCameras: 1);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    await frames.close();
  }

  void scan(String text) => frames.add(BarcodeCapture(
      barcodes: [Barcode(rawValue: text, format: BarcodeFormat.qrCode)]));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late TestScanner camera;
  late MobileScannerPlatform original;
  setUp(() {
    original = MobileScannerPlatform.instance;
    camera = TestScanner();
    MobileScannerPlatform.instance = camera;
  });
  tearDown(() => MobileScannerPlatform.instance = original);

  Future<void> open(
      WidgetTester tester, void Function(StickerScanResult?) onResult) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async => onResult(await Navigator.of(context)
                        .push<StickerScanResult>(MaterialPageRoute(
                            builder: (_) => const DeviceStickerScanScreen()))),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'invalid QR stays open; valid sticker returns once and releases camera',
      (tester) async {
    StickerScanResult? result;
    int returns = 0;
    await open(tester, (value) {
      result = value;
      returns++;
    });
    expect(camera.starts, 1);
    camera.scan('WIFI:S:Home;;');
    await tester.pumpAndSettle();
    expect(returns, 0);
    await tester.scrollUntilVisible(
        find.textContaining('Scan the setup sticker'), 180);
    expect(find.textContaining('Scan the setup sticker'), findsOneWidget);
    camera.scan('DENTRA-DEVICE-1:$qrHardwareId:$qrKey');
    camera.scan('DENTRA-DEVICE-1:$qrHardwareId:$qrKey');
    await tester.pumpAndSettle();
    expect(returns, 1);
    expect(result!.sticker!.key, qrKey);
    expect(result!.sticker!.hardwareId, qrHardwareId);
    expect(camera.stops, 1);
    expect(camera.disposed, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission failure offers manual fallback without a camera',
      (tester) async {
    camera.denied = true;
    StickerScanResult? result;
    await open(tester, (value) => result = value);
    expect(find.textContaining('Allow camera access'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Enter key manually'), 180);
    await tester.tap(find.text('Enter key manually'));
    await tester.pumpAndSettle();
    expect(result!.manual, true);
    expect(camera.disposed, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backgrounding stops camera and resuming restarts it',
      (tester) async {
    await open(tester, (_) {});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(camera.stops, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.starts, 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(camera.disposed, true);
  });
}
