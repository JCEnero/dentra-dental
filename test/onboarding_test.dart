import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dentra_mobile/app/app.dart';
import 'package:dentra_mobile/features/auth/screens/login_screen.dart';
import 'package:dentra_mobile/features/auth/screens/registration_screen.dart';
import 'package:dentra_mobile/features/onboarding/data/onboarding_content.dart';
import 'package:dentra_mobile/features/onboarding/screens/onboarding_screen.dart';
import 'package:dentra_mobile/features/onboarding/services/onboarding_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps long enough for page and route transitions while ambient
/// illustration motion keeps running (so pumpAndSettle would never settle).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _next = find.bySemanticsLabel('Next slide');
final _previous = find.bySemanticsLabel('Previous slide');

String _headline(int i) => onboardingSlides[i].headline;

Future<void> _advanceToLast(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.tap(_next);
    await settle(tester);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void useIPhoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpApp(WidgetTester tester, {bool completed = false}) async {
    useIPhoneView(tester);
    await tester.pumpWidget(
      ProviderScope(child: DentraApp(onboardingCompleted: completed)),
    );
    await tester.pump();
  }

  test('content defines exactly four slides with short copy', () {
    expect(onboardingSlides, hasLength(4));
    expect(_headline(0), 'A CLOSER\nLOOK AT\nYOUR SMILE.');
    expect(_headline(3), 'YOUR SMILE.\nYOUR\nJOURNEY.');
    for (final slide in onboardingSlides) {
      expect(slide.tagline == null || slide.tagline!.length <= 60, isTrue);
    }
  });

  testWidgets('first launch shows onboarding; completed launch shows login',
      (tester) async {
    await pumpApp(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await pumpApp(tester, completed: true);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Next walks all four slides, Back returns', (tester) async {
    await pumpApp(tester);

    expect(find.text(_headline(0)), findsOneWidget);
    expect(_previous, findsNothing, reason: 'no Back on the first slide');

    await tester.tap(_next);
    await settle(tester);
    expect(find.text(_headline(1)), findsOneWidget);

    await tester.tap(_previous);
    await settle(tester);
    expect(find.text(_headline(0)), findsOneWidget);

    await _advanceToLast(tester);
    expect(find.text(_headline(3)), findsOneWidget);
    expect(find.bySemanticsLabel('Get Started'), findsOneWidget);
    expect(find.bySemanticsLabel('Log in'), findsOneWidget);
    expect(_next, findsNothing);
    expect(find.bySemanticsLabel('Skip introduction'), findsNothing);
  });

  testWidgets('system back steps to the previous slide', (tester) async {
    await pumpApp(tester);
    await tester.tap(_next);
    await settle(tester);
    expect(find.text(_headline(1)), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text(_headline(0)), findsOneWidget);
  });

  testWidgets('Get Started persists completion and opens registration',
      (tester) async {
    await pumpApp(tester);
    await _advanceToLast(tester);
    await tester.tap(find.bySemanticsLabel('Get Started'));
    await settle(tester);

    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(await OnboardingStorage.isCompleted(), isTrue);
  });

  testWidgets('Log In on the last slide opens login', (tester) async {
    await pumpApp(tester);
    await _advanceToLast(tester);
    await tester.tap(find.bySemanticsLabel('Log in'));
    await settle(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await OnboardingStorage.isCompleted(), isTrue);
  });

  testWidgets('Skip persists completion and opens login', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Skip introduction'));
    await settle(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await OnboardingStorage.isCompleted(), isTrue);
  });

  testWidgets('replay mode closes back to the caller without auth hand-off',
      (tester) async {
    useIPhoneView(tester);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              Navigator.of(context).push(OnboardingScreen.replayRoute()),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await _advanceToLast(tester);
    expect(find.bySemanticsLabel('Done'), findsOneWidget);
    expect(find.bySemanticsLabel('Log in'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Done'));
    await settle(tester);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
