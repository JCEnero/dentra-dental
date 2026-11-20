import 'package:dentra_mobile/features/camera/state/qr_setup_controller.dart';
import 'package:dentra_mobile/features/camera/widgets/qr_setup_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dentra_mobile/features/camera/widgets/qr_scan_scene.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'reduced motion preserves the 3D stage and truthful status without ticking',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Scaffold(
          body: SingleChildScrollView(
              child: Column(children: [
        QrSetupProgress(
            phase: QrSetupPhase.waiting,
            deviceFound: false,
            qrConfirmed: false,
            waitingLong: true),
      ]))),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for your camera'), findsOneWidget);
    expect(find.textContaining('QR detected.'), findsNothing);
    expect(find.byKey(const ValueKey('qr-device-model')), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('expired setup stops the model animation and offers a fresh QR',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: QrSetupProgress(
          phase: QrSetupPhase.expired, deviceFound: false, qrConfirmed: false),
    ))));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Setup code expired'), findsOneWidget);
    expect(
        tester
            .widget<QrScanScene>(find.byKey(const ValueKey('qr-device-model')))
            .paused,
        true);
    expect(tester.takeException(), isNull);
  });
}
