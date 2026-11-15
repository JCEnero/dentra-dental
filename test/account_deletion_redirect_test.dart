import 'package:dentra_mobile/features/auth/providers/auth_provider.dart';
import 'package:dentra_mobile/features/auth/services/auth_service.dart';
import 'package:dentra_mobile/features/auth/screens/login_screen.dart';
import 'package:dentra_mobile/features/profile/screens/profile_screen.dart';
import 'package:dentra_mobile/features/profile/data/models/user_profile.dart';
import 'package:dentra_mobile/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dentra_mobile/shared/widgets/dentra_glass_ui.dart';

class _TestSessionGate extends ConsumerWidget {
  const _TestSessionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(authServiceProvider).isAuthenticated
          ? const Scaffold(body: ProfileScreen())
          : const LoginScreen();
}

class _TestProfileNotifier extends ProfileNotifier {
  @override
  Future<UserProfile> build() async =>
      const UserProfile(fullName: 'Jane Doe', email: 'jane@example.com');
}

Future<void> _pumpFrames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('successful OTP deletion returns to login', (tester) async {
    final auth = AuthService();
    final result = await tester.runAsync(
      () => auth.signInWithEmail(
        email: 'jane@example.com',
        password: 'secret123',
      ),
    );
    expect(result?.success, isTrue);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => auth),
        profileProvider.overrideWith(_TestProfileNotifier.new),
      ],
      child: const MaterialApp(home: _TestSessionGate()),
    ));
    await _pumpFrames(tester);

    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Delete account'), 300);
    await tester.tap(find.text('Delete account'));
    await _pumpFrames(tester, 4);
    final confirmField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'DELETE',
    );
    await tester.enterText(confirmField, 'DELETE');
    await tester.pump();
    expect(
      tester.widget<TextField>(confirmField).controller!.text,
      'DELETE',
    );
    tester
        .widget<DentraPillButton>(find.byType(DentraPillButton).last)
        .onPressed!
        .call();
    await _pumpFrames(tester, 4);
    expect(find.text('Verify it’s you'), findsOneWidget);
    final otpField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == '6-digit code',
    );
    await tester.enterText(otpField, '123456');
    tester
        .widget<DentraPillButton>(find.byType(DentraPillButton).last)
        .onPressed!
        .call();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });
}
