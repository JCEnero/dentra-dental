import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/api_config.dart';
import 'auth_api.dart';
import 'token_store.dart';

/// Authentication result returned by all auth methods.
class AuthResult {
  final bool success;
  final String? error;
  final String? userId;
  final String? email;

  /// The account exists but its email isn't confirmed yet: show the code
  /// screen for [email] instead of an error.
  final bool needsVerification;

  /// Seconds until another verification code can be requested.
  final int? resendAvailableIn;

  /// Set when the password was right but the account has two-factor on:
  /// show the code screen and finish with [AuthService.verifyTwoFactorSignIn].
  final String? twoFactorToken;

  const AuthResult({
    required this.success,
    this.error,
    this.userId,
    this.email,
    this.needsVerification = false,
    this.resendAvailableIn,
    this.twoFactorToken,
  });

  bool get needsTwoFactor => twoFactorToken != null;
}

/// How [AuthService.restoreSession] ended.
enum SessionRestore {
  /// The server accepted the stored session: the user is signed in.
  restored,

  /// Nothing to restore, or the server rejected it: sign in again.
  signedOut,

  /// A stored session exists but the server couldn't be reached. It is
  /// kept, so trying again can still restore it.
  unreachable,
}

/// DENTRA Auth Service.
///
/// Talks to the DENTRA backend when one is configured (`API_BASE_URL` in
/// `.env`): email/password and Google sign-in, a rotating refresh token kept
/// in secure storage, and an in-memory access token refreshed on demand.
///
/// Without a backend it falls back to demo behaviour, so the UI and widget
/// tests run offline: any password of 6+ characters signs in, and
/// `taken@dentra.com` plays an already-registered email.
class AuthService extends ChangeNotifier {
  AuthService({
    AuthApi? api,
    TokenStore? tokenStore,
    String? googleServerClientId,
  })  : _api = api,
        _tokenStore = tokenStore,
        _googleServerClientId = googleServerClientId;

  /// Uses the backend from `.env` when set, demo mode otherwise.
  factory AuthService.fromEnvironment() {
    final baseUrl = ApiConfig.baseUrl;
    if (baseUrl == null) return AuthService();
    return AuthService(
      api: AuthApi(baseUrl: baseUrl),
      tokenStore: SecureTokenStore(),
      googleServerClientId: ApiConfig.googleServerClientId,
    );
  }

  final AuthApi? _api;
  final TokenStore? _tokenStore;
  final String? _googleServerClientId;

  bool _isAuthenticated = false;
  String? _currentUserId;
  String? _currentEmail;
  String? _currentDisplayName;

  String? _accessToken;
  DateTime? _accessTokenExpiresAt;
  String? _refreshToken;

  /// The refresh in flight, shared so parallel callers never present the
  /// same refresh token twice (the server treats that as theft).
  Future<String?>? _refreshing;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  String? get currentEmail => _currentEmail;
  String? get currentDisplayName => _currentDisplayName;

  /// Whether to offer "Continue with Google": only once it is configured.
  bool get googleSignInAvailable =>
      _api != null && _googleServerClientId != null;

  static const _connectionError =
      "We couldn't reach DENTRA. Check your connection and try again.";
  static const _sessionEndedError =
      'Your session has ended. Please sign in again.';

  // ── Session restore ───────────────────────────────────────────

  /// The restore in flight, shared so a second caller (a hot reload
  /// replaying the launch) never presents the same refresh token twice.
  Future<SessionRestore>? _restoring;

  /// Signs back in from the stored refresh token, once the server has
  /// confirmed it. See [SessionRestore] for the outcomes.
  Future<SessionRestore> restoreSession() {
    if (_isAuthenticated) return Future.value(SessionRestore.restored);
    return _restoring ??= _restore().whenComplete(() => _restoring = null);
  }

  Future<SessionRestore> _restore() async {
    final api = _api;
    final store = _tokenStore;
    if (api == null || store == null) return SessionRestore.signedOut;

    final String? stored;
    try {
      stored = await store.readRefreshToken();
    } catch (_) {
      // Unreadable secure storage: nothing to restore from.
      return SessionRestore.signedOut;
    }
    // Empty means a sign-out could only blank the token (see _endSession).
    if (stored == null || stored.isEmpty) return SessionRestore.signedOut;

    try {
      await _startSession(await api.refresh(stored));
      return SessionRestore.restored;
    } on ApiException catch (e) {
      final serverTrouble =
          e.statusCode >= 500 || e.statusCode == 408 || e.statusCode == 429;
      // Server trouble: keep the token so a retry can use it.
      if (serverTrouble) return SessionRestore.unreachable;
      // Rejected (expired, revoked, malformed): it can never work again.
      try {
        await store.clear();
      } catch (_) {}
      return SessionRestore.signedOut;
    } catch (_) {
      // Offline or timed out: the token is kept for the retry.
      return SessionRestore.unreachable;
    }
  }

  /// A valid access token for calling the DENTRA API, refreshing it when
  /// it is about to expire. Null when signed out or the session ended.
  /// Other API clients (profile, screenings, ...) should get tokens here.
  Future<String?> validAccessToken() async {
    final token = _accessToken;
    final expiresAt = _accessTokenExpiresAt;
    // 30 s margin so a token never expires mid-request.
    if (token != null &&
        expiresAt != null &&
        DateTime.now()
            .isBefore(expiresAt.subtract(const Duration(seconds: 30)))) {
      return token;
    }
    return _refreshing ??= _refreshAccessToken().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<String?> _refreshAccessToken() async {
    final api = _api;
    final refreshToken = _refreshToken;
    if (api == null || refreshToken == null) return null;
    try {
      final session = await api.refresh(refreshToken);
      await _startSession(session);
      return session.accessToken;
    } on ApiException catch (e) {
      if (e.isUnauthenticated) await _endSession();
      return null;
    }
  }

  // ── Email / Password ──────────────────────────────────────────

  /// Sign in with email and password.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final api = _api;
    if (api == null) return _demoSignIn(email, password);

    return _runSignIn(() => api.login(email: email, password: password));
  }

  /// Register with full name, email and password.
  ///
  /// With the backend, this emails a 6-digit code and returns
  /// [AuthResult.needsVerification]; the user is signed in by
  /// [verifyEmail]. Demo mode signs in straight away.
  Future<AuthResult> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final api = _api;
    if (api == null) return _demoRegister(fullName, email);

    try {
      final resendIn = await api.register(
        fullName: fullName,
        email: email,
        password: password,
      );
      return AuthResult(
        success: false,
        needsVerification: true,
        email: email,
        resendAvailableIn: resendIn,
      );
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    }
  }

  // ── Email verification ────────────────────────────────────────

  /// Confirms the code emailed at sign-up and signs the user in.
  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    final api = _api;
    if (api == null) {
      await Future.delayed(const Duration(milliseconds: 900));
      // Demo: '000000' plays the part of a wrong code.
      if (code == '000000') {
        return const AuthResult(
          success: false,
          error: 'That code is incorrect. 4 tries left.',
        );
      }
      _setUser('stub-uid-002', email, null);
      return AuthResult(success: true, userId: _currentUserId, email: email);
    }
    return _runSignIn(() => api.verifyEmail(email: email, code: code));
  }

  /// Emails a new verification code.
  Future<AuthResult> resendVerificationCode({required String email}) async {
    final api = _api;
    if (api == null) {
      await Future.delayed(const Duration(milliseconds: 600));
      return const AuthResult(success: true, resendAvailableIn: 60);
    }
    try {
      final resendIn = await api.resendVerificationCode(email);
      return AuthResult(success: true, resendAvailableIn: resendIn);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────

  /// `GoogleSignIn.initialize` must run exactly once per app launch.
  static Future<void>? _googleInit;

  /// Sign in / sign up with Google.
  ///
  /// The app only obtains a Google ID token; the backend verifies it and
  /// creates or links the DENTRA account. Returns a failed result with no
  /// error when the user closes the Google sheet.
  Future<AuthResult> signInWithGoogle() async {
    final api = _api;
    final serverClientId = _googleServerClientId;
    if (api == null || serverClientId == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      return const AuthResult(
        success: false,
        error: 'Google sign-in is not set up yet. Use your email and '
            'password for now.',
      );
    }

    final google = GoogleSignIn.instance;
    final String? idToken;
    try {
      await (_googleInit ??= google.initialize(serverClientId: serverClientId));
      if (!google.supportsAuthenticate()) {
        return const AuthResult(
          success: false,
          error: "Google sign-in isn't available on this device yet.",
        );
      }
      final account = await google.authenticate();
      idToken = account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const AuthResult(success: false);
      }
      // Lets the next attempt retry initialisation if that is what failed.
      _googleInit = null;
      // Usually a missing SHA-1 / client ID in Google Cloud. Logged for
      // developers; users get a plain message.
      debugPrint('Google sign-in failed: $e');
      return const AuthResult(
        success: false,
        error: "We couldn't sign you in with Google. Please try again.",
      );
    }

    final token = idToken;
    if (token == null) {
      return const AuthResult(
        success: false,
        error: "We couldn't sign you in with Google. Please try again.",
      );
    }
    return _runSignIn(() => api.loginWithGoogle(token));
  }

  // ── Password Reset ────────────────────────────────────────────

  /// Emails a 6-digit reset code. Fails with "No DENTRA account uses that
  /// email." when no account matches.
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    final api = _api;
    if (api == null) {
      await Future.delayed(const Duration(milliseconds: 900));
      return const AuthResult(success: true, resendAvailableIn: 60);
    }
    try {
      final resendIn = await api.forgotPassword(email);
      return AuthResult(
          success: true, email: email, resendAvailableIn: resendIn);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    }
  }

  /// Sets a new password with the emailed code and signs the user in.
  /// Every other device is signed out.
  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final api = _api;
    if (api == null) {
      await Future.delayed(const Duration(milliseconds: 900));
      // Demo: '000000' plays the part of a wrong code.
      if (code == '000000') {
        return const AuthResult(
          success: false,
          error: 'That code is incorrect. 4 tries left.',
        );
      }
      _setUser('stub-uid-001', email, null);
      return AuthResult(success: true, userId: _currentUserId, email: email);
    }
    return _runSignIn(() => api.resetPassword(
          email: email,
          code: code,
          newPassword: newPassword,
        ));
  }

  // ── Change Password ───────────────────────────────────────────

  /// Change the signed-in user's password after re-checking the current
  /// one. Signs out every other device; this one stays signed in.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final api = _api;
    if (api == null) {
      await Future.delayed(const Duration(milliseconds: 1200));
      // Demo: mirrors the demo sign-in, which rejects passwords under 6.
      if (currentPassword.length < 6) {
        return const AuthResult(
          success: false,
          error: 'Your current password is incorrect.',
        );
      }
      return const AuthResult(success: true);
    }

    final accessToken = await validAccessToken();
    if (accessToken == null) {
      return const AuthResult(success: false, error: _sessionEndedError);
    }
    try {
      await _startSession(await api.changePassword(
        accessToken: accessToken,
        currentPassword: currentPassword,
        newPassword: newPassword,
      ));
      return AuthResult(success: true, userId: _currentUserId);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    }
  }

  // ── Two-Factor Authentication ─────────────────────────────────
  // Email codes on top of the password. Google sign-in skips the second
  // step on the server, since Google already proves the same inbox.

  /// Finishes a password sign-in that needed a code (see
  /// [AuthResult.needsTwoFactor]).
  Future<AuthResult> verifyTwoFactorSignIn({
    required String challengeToken,
    required String code,
  }) async {
    final api = _api;
    if (api == null) return _demoCode(code, signInAs: 'stub-uid-001');
    return _runSignIn(() => api.verifyTwoFactor(
          challengeToken: challengeToken,
          code: code,
        ));
  }

  /// Emails another sign-in code for a pending two-factor sign-in.
  Future<AuthResult> resendTwoFactorSignInCode({
    required String challengeToken,
  }) async {
    final api = _api;
    if (api == null) {
      await Future.delayed(const Duration(milliseconds: 600));
      return const AuthResult(success: true, resendAvailableIn: 60);
    }
    try {
      final resendIn = await api.resendTwoFactor(challengeToken);
      return AuthResult(success: true, resendAvailableIn: resendIn);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    }
  }

  /// Emails the signed-in user a code that confirms turning 2FA on or off.
  Future<AuthResult> sendTwoFactorCode() async {
    final api = _api;
    if (api == null) {
      await Future.delayed(const Duration(milliseconds: 800));
      return const AuthResult(success: true, resendAvailableIn: 30);
    }
    final accessToken = await validAccessToken();
    if (accessToken == null) {
      return const AuthResult(success: false, error: _sessionEndedError);
    }
    try {
      final resendIn = await api.sendTwoFactorCode(accessToken: accessToken);
      return AuthResult(success: true, resendAvailableIn: resendIn);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    }
  }

  /// Turns two-factor on ([enable]) or off with the emailed code.
  Future<AuthResult> setTwoFactor({
    required String code,
    required bool enable,
  }) async {
    final api = _api;
    if (api == null) return _demoCode(code);
    final accessToken = await validAccessToken();
    if (accessToken == null) {
      return const AuthResult(success: false, error: _sessionEndedError);
    }
    try {
      await api.setTwoFactor(
        accessToken: accessToken,
        code: code,
        enabled: enable,
      );
      return const AuthResult(success: true);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    }
  }

  /// Demo: '000000' plays the part of a wrong code. [signInAs] signs the
  /// demo user in on success.
  Future<AuthResult> _demoCode(String code, {String? signInAs}) async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (code == '000000') {
      return const AuthResult(
        success: false,
        error: 'That code is incorrect. 4 tries left.',
      );
    }
    if (signInAs != null) _setUser(signInAs, _currentEmail, null);
    return AuthResult(success: true, userId: _currentUserId);
  }

  // ── Account ───────────────────────────────────────────────────

  /// Keep the session's name and email in step after a profile edit.
  void updateIdentity({String? displayName, String? email}) {
    if (!_isAuthenticated) return;
    _currentDisplayName = displayName ?? _currentDisplayName;
    _currentEmail = email ?? _currentEmail;
    notifyListeners();
  }

  /// Permanently delete the signed-in account, then sign out.
  Future<AuthResult> deleteAccount() async {
    final api = _api;
    if (api == null) {
      await Future.delayed(const Duration(milliseconds: 1400));
      await _endSession();
      return const AuthResult(success: true);
    }

    try {
      final accessToken = await validAccessToken();
      if (accessToken == null) {
        return const AuthResult(success: false, error: _sessionEndedError);
      }
      await api.deleteAccount(accessToken: accessToken);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    } catch (_) {
      return const AuthResult(success: false, error: _connectionError);
    }
    await _signOutOfGoogle();
    await _endSession();
    return const AuthResult(success: true);
  }

  // ── Sign Out ──────────────────────────────────────────────────

  /// Sign out the current user. Always clears the local session, even if
  /// the server can't be told.
  Future<void> signOut() async {
    final api = _api;
    final refreshToken = _refreshToken;
    await _endSession();
    await _signOutOfGoogle();
    if (api != null && refreshToken != null) {
      try {
        await api.logout(refreshToken);
      } catch (_) {
        // The token expires on its own; nothing else to do offline.
      }
    }
  }

  // ── Internal helpers ──────────────────────────────────────────

  /// Runs a backend sign-in and turns API errors into an [AuthResult].
  /// Network errors are rethrown for the screen's connection message.
  Future<AuthResult> _runSignIn(Future<AuthSession> Function() call) async {
    try {
      final session = await call();
      await _startSession(session);
      return AuthResult(
        success: true,
        userId: session.userId,
        email: session.email,
      );
    } on TwoFactorRequired catch (e) {
      // Right password, second step on: the server just emailed a code.
      return AuthResult(
        success: false,
        email: e.email,
        twoFactorToken: e.challengeToken,
        resendAvailableIn: e.resendAvailableIn,
      );
    } on ApiException catch (e) {
      // Right password, unfinished sign-up: the server just emailed a code.
      if (e.code == 'email_not_verified') {
        return AuthResult(
          success: false,
          needsVerification: true,
          error: e.message,
        );
      }
      return AuthResult(success: false, error: e.message);
    }
  }

  Future<void> _startSession(AuthSession session) async {
    _accessToken = session.accessToken;
    _accessTokenExpiresAt = session.accessTokenExpiresAt;
    _refreshToken = session.refreshToken;
    await _tokenStore?.writeRefreshToken(session.refreshToken);
    _setUser(session.userId, session.email, session.fullName);
  }

  Future<void> _endSession() async {
    _accessToken = null;
    _accessTokenExpiresAt = null;
    _refreshToken = null;
    // Sign the user out in memory first, so a storage error can't keep
    // them in.
    _clearUser();
    final store = _tokenStore;
    if (store == null) return;
    try {
      await store.clear();
    } catch (_) {
      // Deleting failed: blank the token instead, so the next launch
      // can't restore this session from it.
      try {
        await store.writeRefreshToken('');
      } catch (_) {}
    }
  }

  /// Lets the next Google sign-in offer the account picker again.
  Future<void> _signOutOfGoogle() async {
    if (_googleInit == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google on this device.
    }
  }

  Future<AuthResult> _demoSignIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (password.length < 6) {
      return const AuthResult(
        success: false,
        error: 'Invalid credentials. Please check your email and password.',
      );
    }
    _setUser('stub-uid-001', email, null);
    return AuthResult(success: true, userId: _currentUserId, email: email);
  }

  Future<AuthResult> _demoRegister(String fullName, String email) async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (email.toLowerCase() == 'taken@dentra.com') {
      return const AuthResult(
        success: false,
        error: 'An account with this email already exists.',
      );
    }
    _setUser('stub-uid-002', email, fullName);
    return AuthResult(success: true, userId: _currentUserId, email: email);
  }

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
