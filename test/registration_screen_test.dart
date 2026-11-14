import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dentra_mobile/features/auth/screens/login_screen.dart';
import 'package:dentra_mobile/features/auth/screens/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pumps through route transitions and the stub service's simulated latency.
Future<void> settle(WidgetTester tester, {int steps = 12}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _field(int i) => find.byType(TextField).at(i);
const _name = 0, _email = 1, _password = 2, _confirm = 3;
final _create = find.bySemanticsLabel('Create account');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpRegistration(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: const RegistrationScreen(),
        routes: {'/home': (_) => const Scaffold(body: Text('HOME'))},
      ),
    ));
    await settle(tester, steps: 6);
  }

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Jane Cruz',
    String email = 'jane@example.com',
    String password = 'Secret123!',
    String? confirm,
  }) async {
    await tester.enterText(_field(_name), name);
    await tester.enterText(_field(_email), email);
    await tester.enterText(_field(_password), password);
    await tester.enterText(_field(_confirm), confirm ?? password);
  }

  testWidgets('matches the login design; Google hidden until configured',
      (tester) async {
    await pumpRegistration(tester);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Your smile journey starts here.'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('Sign up with Google'), findsNothing);
  });

  testWidgets('no errors before interaction; submit validates every field',
      (tester) async {
    await pumpRegistration(tester);
    expect(find.text('Enter your full name.'), findsNothing);

    await tester.tap(_create);
    await tester.pump();
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Create a password.'), findsOneWidget);
    expect(find.text('Re-enter your password.'), findsOneWidget);
  });

  testWidgets('fields validate on blur and confirm tracks the password',
      (tester) async {
    await pumpRegistration(tester);
    await tester.enterText(_field(_email), 'jane@');
    await tester.enterText(_field(_password), 'short');
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget,
        reason: 'email blurred when focus moved to password');

    await tester.enterText(_field(_confirm), 'shorx');
    await tester.pump();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text("Passwords don't match."), findsOneWidget);

    // Fixing the password side clears the mismatch live.
    await tester.enterText(_field(_password), 'shorx');
    await tester.pump();
    expect(find.text("Passwords don't match."), findsNothing);
  });

  testWidgets('shows password strength while typing', (tester) async {
    await pumpRegistration(tester);
    await tester.enterText(_field(_password), 'abc');
    await tester.pump();
    expect(find.text('Weak'), findsOneWidget);
    await tester.enterText(_field(_password), 'Secret123!');
    await tester.pump();
    expect(find.text('Very Strong'), findsOneWidget);
  });

  testWidgets('loading state, then the service error', (tester) async {
    await pumpRegistration(tester);
    await fill(tester, email: 'taken@dentra.com'); // stub's duplicate email
    await tester.tap(_create);
    await tester.pump();

    expect(find.bySemanticsLabel('Creating account…'), findsOneWidget);
    expect(_create, findsNothing);

    await settle(tester, steps: 20);
    expect(find.text('An account with this email already exists.'),
        findsOneWidget);
    expect(_create, findsOneWidget);
  });

  testWidgets('successful sign-up replaces the stack with /home',
      (tester) async {
    await pumpRegistration(tester);
    await fill(tester);
    await tester.tap(_create);
    await settle(tester, steps: 22);

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(RegistrationScreen), findsNothing);
  });

  testWidgets('Log in opens the login screen', (tester) async {
    await pumpRegistration(tester);
    await tester.tap(find.text('Log in'));
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegistrationScreen), findsNothing);
  });

  testWidgets('terms and privacy links open their sheets', (tester) async {
    await pumpRegistration(tester);
    await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
    await settle(tester, steps: 6);
    expect(find.text('Got it'), findsOneWidget);
    expect(
        find.textContaining('collects only the information'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Got it'));
    await settle(tester, steps: 6);
    await tester.tapOnText(find.textRange.ofSubstring('Terms of Service'));
    await settle(tester, steps: 6);
    expect(find.textContaining('does not constitute medical advice'),
        findsOneWidget);
  });

  testWidgets('keyboard open keeps Create Account visible', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 280 * 3);
    await pumpRegistration(tester, size: const Size(360, 640));
    await tester.showKeyboard(_field(_password));
    await tester.pump();

    expect(tester.getRect(_create).bottom, lessThanOrEqualTo(640 - 280));
    expect(find.text('Log in'), findsNothing);
  });

  testWidgets('no overflow on a small screen with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpRegistration(tester, size: const Size(320, 568));
    await tester.tap(_create);
    await settle(tester, steps: 4);
    expect(tester.takeException(), isNull);
  });
}
