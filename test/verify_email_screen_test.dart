import 'package:dentra_mobile/features/auth/screens/verify_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pumps through transitions and the demo service's simulated latency.
Future<void> settle(WidgetTester tester, {int steps = 12}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _code = find.byType(TextField);
final _verify = find.bySemanticsLabel('Verify email');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpVerify(
    WidgetTester tester, {
    int resendAvailableIn = 60,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: VerifyEmailScreen(
          email: 'jane@example.com',
          resendAvailableIn: resendAvailableIn,
        ),
        routes: {'/home': (_) => const Scaffold(body: Text('HOME'))},
      ),
    ));
    await settle(tester, steps: 6);
  }

  testWidgets('names the email and holds resend during the cooldown',
      (tester) async {
    await pumpVerify(tester, resendAvailableIn: 3);
    expect(find.text('We sent a 6-digit code to jane@example.com.'),
        findsOneWidget);
    expect(find.text('Resend in 3s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend in 2s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Resend code'), findsOneWidget);
  });

  testWidgets('only digits are accepted, at most six', (tester) async {
    await pumpVerify(tester);
    await tester.enterText(_code, '12ab34');
    await tester.pump();
    expect(tester.widget<TextField>(_code).controller!.text, '1234');
  });

  testWidgets('submitting a short code asks for six digits', (tester) async {
    await pumpVerify(tester);
    await tester.enterText(_code, '123');
    await tester.tap(_verify);
    await tester.pump();
    expect(find.text('Enter the 6-digit code.'), findsOneWidget);
  });

  testWidgets('a wrong code shows the error and clears the field',
      (tester) async {
    await pumpVerify(tester);
    await tester.enterText(_code, '000000'); // demo: wrong code
    await tester.pump();
    expect(find.bySemanticsLabel('Verifying…'), findsOneWidget);

    await settle(tester);
    expect(find.text('That code is incorrect. 4 tries left.'), findsOneWidget);
    expect(tester.widget<TextField>(_code).controller!.text, isEmpty);
  });

  testWidgets('the sixth digit verifies and opens the app', (tester) async {
    await pumpVerify(tester);
    await tester.enterText(_code, '123456');
    await settle(tester, steps: 16);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('resending confirms and restarts the cooldown', (tester) async {
    await pumpVerify(tester, resendAvailableIn: 0);
    await tester.tap(find.text('Resend code'));
    await settle(tester, steps: 8);
    expect(find.text('A new code is on its way to jane@example.com.'),
        findsOneWidget);
    expect(find.textContaining('Resend in'), findsOneWidget);
  });

  testWidgets('no overflow on a small screen with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpVerify(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(_verify, findsOneWidget);
  });
}
