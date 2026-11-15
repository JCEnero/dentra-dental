import 'dart:async';

import 'package:dentra_mobile/features/auth/services/auth_service.dart';
import 'package:dentra_mobile/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dentra_mobile/features/auth/screens/login_screen.dart';
import 'package:dentra_mobile/features/auth/screens/registration_screen.dart';
import 'package:dentra_mobile/features/auth/screens/reset_password_screen.dart';
import 'package:dentra_mobile/features/dental_profile/providers/dental_profile_providers.dart';
import 'package:dentra_mobile/features/splash/screens/session_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_dental_profile_repository.dart';

/// Pumps through route transitions and the stub service's simulated latency.
Future<void> settle(WidgetTester tester, {int steps = 12}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _email = find.byType(TextField).first;
final _password = find.byType(TextField).last;
final _logIn = find.bySemanticsLabel('Log in');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpLogin(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        // Demo auth only via this explicit override (the app fails closed).
        overrides: [authServiceProvider.overrideWith((ref) => AuthService())],
        child: MaterialApp(
          home: const LoginScreen(),
          routes: {'/home': (_) => const Scaffold(body: Text('HOME'))},
        ),
      ),
    );
    await settle(tester, steps: 6);
  }

  testWidgets('shows the redesigned content; Google hidden until configured', (
    tester,
  ) async {
    await pumpLogin(tester);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Your smile journey continues.'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('no errors before interaction; submit validates both fields', (
    tester,
  ) async {
    await pumpLogin(tester);
    expect(find.text('Enter your email address.'), findsNothing);

    await tester.tap(_logIn);
    await tester.pump();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);

    // Errors clear live once fixed.
    await tester.enterText(_email, 'jane@mail.example.com');
    await tester.pump();
    expect(find.text('Enter your email address.'), findsNothing);
    expect(find.text('Enter a valid email address.'), findsNothing);
  });

  testWidgets('email is validated when the field loses focus', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(_email, 'jane@');
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsNothing);

    await tester.tap(_password);
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('password visibility toggles', (tester) async {
    await pumpLogin(tester);
    bool obscured() => tester.widget<TextField>(_password).obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(obscured(), isTrue);
  });

  testWidgets('shows loading, blocks resubmits, then the service error', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.enterText(_email, 'jane@example.com');
    await tester.enterText(_password, '123'); // stub rejects < 6 chars
    await tester.tap(_logIn);
    await tester.pump();

    expect(find.bySemanticsLabel('Logging in…'), findsOneWidget);
    expect(_logIn, findsNothing);

    await settle(tester, steps: 16);
    expect(
      find.text('Invalid credentials. Please check your email and password.'),
      findsOneWidget,
    );
    expect(_logIn, findsOneWidget);

    // Editing a field dismisses the error.
    await tester.enterText(_password, '1234');
    await tester.pump();
    expect(
      find.text('Invalid credentials. Please check your email and password.'),
      findsNothing,
    );
  });

  testWidgets('allows correcting a rejected password and logging in again', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.enterText(_email, 'jane@example.com');
    await tester.enterText(_password, 'wrong');
    await tester.tap(_logIn);
    await settle(tester, steps: 16);

    expect(
      find.text('Invalid credentials. Please check your email and password.'),
      findsOneWidget,
    );
    expect(_logIn, findsOneWidget);

    await tester.enterText(_password, 'secret123');
    await tester.tap(_logIn);
    await settle(tester, steps: 20);
    // The corrected password signs in: the stack is replaced with '/home'.
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('successful login shows the loader, which lets the user in '
      'only once their data has loaded', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // A returning user whose onboarding status answers only when released.
    final status = Completer<void>();
    final repo = FakeDentalProfileRepository.completed()..holdStatus = status;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Demo auth only via this explicit override (the app fails closed).
          authServiceProvider.overrideWith((ref) => AuthService()),
          dentalProfileRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: const LoginScreen(),
          // The real '/home' is the loader, in front of the app.
          routes: {
            '/home': (_) =>
                const SessionLoader(app: Scaffold(body: Text('HOME'))),
          },
        ),
      ),
    );
    await settle(tester, steps: 6);

    await tester.enterText(_email, 'jane@example.com');
    await tester.enterText(_password, 'secret123');
    await tester.tap(_logIn);
    await settle(tester, steps: 20);

    expect(find.byType(SessionLoader), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    // Still waiting on the dental profile: well past any animation, the
    // app must not show.
    await settle(tester, steps: 60);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('Loading your dental profile…'), findsOneWidget);

    status.complete();
    await settle(tester, steps: 60);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('Sign up opens the registration screen', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.text('Sign up'));
    await settle(tester);
    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Forgot password validates in the dialog, then sends', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.tap(find.text('Forgot password?'));
    await settle(tester, steps: 4);
    expect(find.text('Reset password'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Send code'));
    await tester.pump();
    expect(find.text('Enter your email address.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'jane@example.com');
    await tester.tap(find.bySemanticsLabel('Send code'));
    await settle(tester, steps: 4);
    // The dialog stays up while the code is sent, then hands over.
    expect(find.text('Reset password'), findsOneWidget);

    await settle(tester, steps: 14);
    expect(find.text("Enter your email and we'll send you a 6-digit code."),
        findsNothing);
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
  });

  testWidgets('keyboard open keeps Log In visible and hides the sign-up link', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 280 * 3);
    await pumpLogin(tester, size: const Size(360, 640));
    await tester.showKeyboard(_email);
    await tester.pump();

    final button = tester.getRect(_logIn);
    expect(button.bottom, lessThanOrEqualTo(640 - 280));
    expect(find.text('Sign up'), findsNothing);
  });

  testWidgets('no overflow on a small screen with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpLogin(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(_logIn, findsOneWidget);
  });
}
