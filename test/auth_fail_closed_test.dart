import 'package:dentra_mobile/features/auth/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Without API_BASE_URL (tests never load `.env`), the app's auth must not
/// fall back to demo sign-in: no password, right or wrong, grants access.
void main() {
  test('no backend configured: sign-in, sign-up and code checks fail closed',
      () async {
    final auth = AuthService.fromEnvironment();
    expect(auth.usesBackend, isFalse);

    final signIn = await auth.signInWithEmail(
      email: 'jane@example.com',
      password: 'any-long-password',
    );
    expect(signIn.success, isFalse);
    expect(auth.isAuthenticated, isFalse);

    final register = await auth.registerWithEmail(
      fullName: 'Jane',
      email: 'jane@example.com',
      password: 'Secret123!',
    );
    expect(register.success, isFalse);

    final verify =
        await auth.verifyEmail(email: 'jane@example.com', code: '123456');
    expect(verify.success, isFalse);

    final twoFactor = await auth.verifyTwoFactorSignIn(
      challengeToken: 't',
      code: '123456',
    );
    expect(twoFactor.success, isFalse);
    expect(auth.isAuthenticated, isFalse);
  });
}
