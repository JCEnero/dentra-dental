import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dentra_mobile/features/scan/providers/scan_flow_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real PNG, so the check decodes it the way it would a photo.
Future<Uint8List> _png((int, int, int) Function(int x, int y) color) async {
  const w = 120, h = 90;
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final (r, g, b) = color(x, y);
      final i = (y * w + x) * 4;
      px
        ..[i] = r
        ..[i + 1] = g
        ..[i + 2] = b
        ..[i + 3] = 255;
    }
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, done.complete);
  final image = await done.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('a photo without teeth is rejected, and a retake replaces it',
      (tester) async {
    await tester.runAsync(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final flow = container.read(scanFlowProvider.notifier);

      final landscape = await _png(
          (x, y) => y < 45 ? (120, 170, 230) : (60, 140, 50));
      final mouth = await _png((x, y) =>
          y > 30 && y < 60 && x % 14 > 2 ? (238, 230, 206) : (196, 72, 92));

      expect(await flow.setPhoto('r1', landscape), PhotoCheck.rejected);
      var state = container.read(scanFlowProvider);
      expect(state.photos['r1']!.check, PhotoCheck.rejected);
      expect(state.capturedCount, 0);
      expect(state.canStartScan, isFalse);

      // Retake.
      expect(await flow.setPhoto('r1', mouth), PhotoCheck.passed);
      state = container.read(scanFlowProvider);
      expect(state.capturedCount, 1);
      expect(state.canStartScan, isTrue);
    });
  });

  testWidgets('sample photos skip the check', (tester) async {
    await tester.runAsync(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final blank = await _png((_, __) => (245, 245, 242));

      final check = await container
          .read(scanFlowProvider.notifier)
          .setPhoto('r1', blank, sample: true);
      expect(check, PhotoCheck.passed);
    });
  });
}
