import 'package:dentra_mobile/app/app.dart';
import 'package:dentra_mobile/features/auth/providers/auth_provider.dart';
import 'package:dentra_mobile/features/auth/screens/login_screen.dart';
import 'package:dentra_mobile/features/auth/services/auth_service.dart';
import 'package:dentra_mobile/features/dental_profile/providers/dental_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/fake_dental_profile_repository.dart';

/// The app must never open without a live session, however it is reached.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpRoute(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      // Demo auth only via this explicit override (the app fails closed).
      overrides: [authServiceProvider.overrideWith((ref) => AuthService())],
      child: MaterialApp(
        home: home,
        routes: {'/home': (_) => const SignedInGate()},
      ),
    ));
    await tester.pump();
  }

  testWidgets('signed out, the gate shows sign-in instead of the app',
      (tester) async {
    await pumpRoute(tester, const SignedInGate());
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('navigating to /home signed out still lands on sign-in',
      (tester) async {
    await pumpRoute(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/home'),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('signing out leaves exactly one sign-in screen, with no back',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final auth = AuthService(); // demo mode
    // Demo sign-in waits on a real timer, so run it outside fake time.
    await tester.runAsync(() => auth.signInWithEmail(
          email: 'user@dentra.com',
          password: 'secret123',
        ));
    expect(auth.isAuthenticated, isTrue);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => auth),
        // A returning user: dental onboarding already done.
        dentalProfileRepositoryProvider
            .overrideWithValue(FakeDentalProfileRepository.completed()),
      ],
      child: MaterialApp(
        navigatorKey: navKey,
        home: const SignedInGate(app: Scaffold(body: Text('APP'))),
      ),
    ));
    // The gate first confirms onboarding is done.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('APP'), findsOneWidget);

    // A screen above the shell, like notifications, then sign out the way
    // the profile and notifications screens do.
    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('ABOVE')),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await auth.signOut();
    navKey.currentState!.popUntil((route) => route.isFirst);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('APP'), findsNothing);
    expect(find.text('ABOVE'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });
}
