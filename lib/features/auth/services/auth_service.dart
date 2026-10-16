import 'package:flutter/foundation.dart';

/// Authentication result returned by all auth methods.
class AuthResult {
  final bool success;
  final String? error;
  final String? userId;
  final String? email;

  const AuthResult({
    required this.success,
    this.error,
    this.userId,
    this.email,
  });
}

/// DENTRA Auth Service.
///
/// Currently provides stub implementations for email/password and Google Sign-In.
/// Replace the method bodies with your actual backend calls (Firebase, Supabase,
/// custom REST API, etc.) without changing the public API surface.
class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _currentUserId;
  String? _currentEmail;
  String? _currentDisplayName;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  String? get currentEmail => _currentEmail;
  String? get currentDisplayName => _currentDisplayName;

  // ── Email / Password ──────────────────────────────────────────

  /// Sign in with email and password.
  /// Replace the body with your actual authentication API call.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 1400));

    // ── TODO: Replace with real backend call ──────────────────
    // Example (Firebase):
    //   final credential = await FirebaseAuth.instance
    //       .signInWithEmailAndPassword(email: email, password: password);
    //   _setUser(credential.user?.uid, email, credential.user?.displayName);
    //   return AuthResult(success: true, userId: credential.user?.uid, email: email);
    //
    // Example (custom REST):
    //   final response = await http.post(
    //     Uri.parse('$baseUrl/auth/login'),
    //     body: jsonEncode({'email': email, 'password': password}),
    //   );
    //   if (response.statusCode == 200) { ... } else { ... }
    // ─────────────────────────────────────────────────────────

    // Stub: treat any well-formed email + non-empty password as success
    if (password.length < 6) {
      return const AuthResult(
        success: false,
        error: 'Invalid credentials. Please check your email and password.',
      );
    }

    _setUser('stub-uid-001', email, null);
    return AuthResult(success: true, userId: _currentUserId, email: email);
  }

  /// Register with full name, email and password.
  /// Replace the body with your actual registration API call.
  Future<AuthResult> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1600));

    // ── TODO: Replace with real backend call ──────────────────
    // Example (Firebase):
    //   final credential = await FirebaseAuth.instance
    //       .createUserWithEmailAndPassword(email: email, password: password);
    //   await credential.user?.updateDisplayName(fullName);
    //   _setUser(credential.user?.uid, email, fullName);
    //   return AuthResult(success: true, userId: credential.user?.uid, email: email);
    // ─────────────────────────────────────────────────────────

    // Stub: simulate duplicate email for demo
    if (email.toLowerCase() == 'taken@dentra.com') {
      return const AuthResult(
        success: false,
        error: 'An account with this email already exists.',
      );
    }

    _setUser('stub-uid-002', email, fullName);
    return AuthResult(success: true, userId: _currentUserId, email: email);
  }

  // ── Google Sign-In ────────────────────────────────────────────

  /// Sign in / sign up with Google.
  ///
  /// Prerequisites to enable:
  ///  1. Add `google_sign_in: ^6.x.x` to pubspec.yaml
  ///  2. Add `firebase_auth` or your OAuth handler
  ///  3. Place google-services.json (Android) / GoogleService-Info.plist (iOS)
  ///  4. Configure OAuth client ID in Google Cloud Console
  ///
  /// Replace this stub with the real implementation once configured.
  Future<AuthResult> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 800));

    // ── TODO: Replace with real Google Sign-In ────────────────
    // Example (google_sign_in + Firebase):
    //   final googleUser = await GoogleSignIn().signIn();
    //   if (googleUser == null) return AuthResult(success: false, error: 'Cancelled');
    //   final googleAuth = await googleUser.authentication;
    //   final credential = GoogleAuthProvider.credential(
    //     accessToken: googleAuth.accessToken,
    //     idToken: googleAuth.idToken,
    //   );
    //   final userCredential =
    //       await FirebaseAuth.instance.signInWithCredential(credential);
    //   _setUser(userCredential.user?.uid, googleUser.email, googleUser.displayName);
    //   return AuthResult(success: true, ...);
    // ─────────────────────────────────────────────────────────

    return const AuthResult(
      success: false,
      error:
          'Google Sign-In is not configured yet. Add google_sign_in and your '
          'OAuth credentials to enable this feature.',
    );
  }

  // ── Password Reset ────────────────────────────────────────────

  /// Send a password reset email.
  /// Replace with your actual password reset implementation.
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 900));

    // ── TODO: Replace with real password reset ────────────────
    // Example (Firebase):
    //   await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    //   return AuthResult(success: true);
    // ─────────────────────────────────────────────────────────

    return const AuthResult(success: true);
  }

  // ── Sign Out ──────────────────────────────────────────────────

  /// Sign out the current user.
  Future<void> signOut() async {
    // TODO: FirebaseAuth.instance.signOut() / GoogleSignIn().signOut()
    _clearUser();
  }

  // ── Internal helpers ──────────────────────────────────────────

  void _setUser(String? uid, String? email, String? name) {
    _isAuthenticated = true;
    _currentUserId = uid;
    _currentEmail = email;
    _currentDisplayName = name;
    notifyListeners();
  }

  void _clearUser() {
    _isAuthenticated = false;
    _currentUserId = null;
    _currentEmail = null;
    _currentDisplayName = null;
    notifyListeners();
  }
}
