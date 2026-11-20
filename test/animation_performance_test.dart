import 'package:dentra_mobile/features/scan/widgets/scan_theme.dart';
import 'package:dentra_mobile/shared/widgets/gloss_pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void _onPressed() {}

Widget _host(Widget child, {bool reduced = false, bool visible = true}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(
          enabled: visible,
          child: Center(child: SizedBox(width: 300, child: child)),
        ),
      ),
    );

class _PaintCounter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('gloss sheen schedules frames only during its visible pass',
      (tester) async {
    await tester.pumpWidget(_host(const GlossPillButton(
      label: 'Continue',
      onPressed: _onPressed,
    )));
    // Finish MaterialApp's first-frame setup before checking idle work.
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  for (final reduced in [false, true]) {
    testWidgets('hidden and disabled sheen rests (reduced motion: $reduced)',
        (tester) async {
      const enabled = GlossPillButton(
        label: 'Continue',
        onPressed: _onPressed,
      );
      await tester.pumpWidget(_host(enabled, reduced: reduced));
      await tester.pump(const Duration(milliseconds: 1980));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(_host(enabled, reduced: reduced, visible: false));
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_host(
        const GlossPillButton(label: 'Continue', onPressed: null),
        reduced: reduced,
      ));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_host(enabled, reduced: reduced));
      await tester.pump(const Duration(milliseconds: 1980));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, !reduced);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('gloss sheen never repaints the surrounding page',
      (tester) async {
    final page = _PaintCounter();
    await tester.pumpWidget(_host(CustomPaint(
      painter: page,
      child: const GlossPillButton(
        label: 'Continue',
        onPressed: _onPressed,
      ),
    )));
    final initialPaints = page.paints;
    expect(initialPaints, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 1980));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(page.paints, initialPaints);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('scan glow never repaints the surrounding page', (tester) async {
    final page = _PaintCounter();
    await tester.pumpWidget(_host(CustomPaint(
      painter: page,
      child: const GlowButton(label: 'Start scan', onTap: _onPressed),
    )));
    final initialPaints = page.paints;
    expect(initialPaints, greaterThan(0));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(page.paints, initialPaints);
    await tester.tap(find.text('Start scan'));
    await tester.pumpWidget(const SizedBox());
  });
}
