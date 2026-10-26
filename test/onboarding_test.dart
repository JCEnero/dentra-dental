import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dentra_mobile/app/app.dart';
import 'package:dentra_mobile/features/auth/screens/login_screen.dart';
import 'package:dentra_mobile/features/auth/screens/registration_screen.dart';
import 'package:dentra_mobile/features/onboarding/data/onboarding_content.dart';
import 'package:dentra_mobile/features/onboarding/screens/onboarding_screen.dart';
import 'package:dentra_mobile/features/onboarding/services/onboarding_storage.dart';
import 'package:dentra_mobile/features/splash/screens/splash_screen.dart';
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

/// Runs the launch animation and its fade into the next screen.
Future<void> _runSplash(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _next = find.bySemanticsLabel('Next slide');
final _previous = find.bySemanticsLabel('Previous slide');

String _headline(int i) => onboardingSlides[i].headline;

Future<void> _advanceToLast(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
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

  test('content defines exactly three slides with the welcome copy', () {
    expect(onboardingSlides, hasLength(3));
    expect(_headline(0), 'Meet DENTRA');
    expect(_headline(1), 'See Your Smile Differently');
    expect(_headline(2), 'Your Smile, Your Journey');
    expect(onboardingSlides[0].description,
        'Your companion for smarter oral health monitoring.');
    expect(
        onboardingSlides[1].description,
        'Explore AI-assisted dental screening designed to help you monitor '
        'your oral health.');
    expect(
        onboardingSlides[2].description,
        'Keep track of your screening history and stay informed about your '
        'oral health over time.');
  });

  for (final (name, size, textScale) in const [
    ('small phone', Size(320, 568), 1.0),
    ('small phone, large text', Size(360, 640), 1.6),
    ('large phone', Size(430, 932), 1.0),
    ('tablet', Size(820, 1180), 1.0),
  ]) {
    testWidgets('every slide lays out without overflow on a $name',
        (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        expect(find.text(_headline(i)), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (i < 2) {
          await tester.tap(_next);
          await settle(tester);
        }
      }
      expect(find.bySemanticsLabel('Get Started'), findsOneWidget);
    });
  }

  testWidgets(
      'first launch shows onboarding; completed launch plays the splash, '
      'then shows login', (tester) async {
    await pumpApp(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await pumpApp(tester, completed: true);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Run the launch animation out, then the fade into login.
    await _runSplash(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    // Login is the root screen: nothing to go back to.
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets(
      'a web refresh on #/home signed out still plays the splash, then '
      'login with no back button', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/home';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await pumpApp(tester, completed: true);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing,
        reason: 'nothing may be stacked over the splash from the URL');

    await _runSplash(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('hot reload replays the splash, then login with no back button',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.completed.v1': true,
    });
    await pumpApp(tester, completed: true);
    await _runSplash(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    tester.binding.reassembleApplication();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LoginScreen), findsNothing,
        reason: 'the splash plays before login comes back');

    await _runSplash(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('Next walks all three slides, Back returns', (tester) async {
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
    expect(find.text(_headline(2)), findsOneWidget);
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
