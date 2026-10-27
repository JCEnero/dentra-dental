import '../../../core/network/api_client.dart';

export '../../../core/network/api_client.dart' show ApiException;

/// Tokens and user returned by every successful sign-in or refresh.
class AuthSession {
  final String accessToken;
  final String refreshToken;

  /// When [accessToken] stops working, per the server's `expires_in`.
  final DateTime accessTokenExpiresAt;

  /// The `user` object; keys match `UserProfile.fromJson`.
  final Map<String, dynamic> user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.user,
  });

  String get userId => user['id'] as String;
  String get email => user['email'] as String;
  String? get fullName => user['full_name'] as String?;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final expiresIn = json['expires_in'] as int? ?? 0;
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      accessTokenExpiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      user: json['user'] as Map<String, dynamic>,
    );
  }
}

/// Thrown by [AuthApi.login] when the password was right but the account
/// has two-factor on: a code was emailed, and [AuthApi.verifyTwoFactor]
/// with [challengeToken] and that code finishes the sign-in.
class TwoFactorRequired implements Exception {
  final String challengeToken;
  final String email;

  /// Seconds until another code can be requested.
  final int resendAvailableIn;

  const TwoFactorRequired({
    required this.challengeToken,
    required this.email,
    required this.resendAvailableIn,
  });

  @override
  String toString() => 'TwoFactorRequired($email)';
}

/// The DENTRA backend's `/api/auth` endpoints, plus account deletion.
///
/// Errors are [ApiException]s; network failures surface as the usual
/// `http`/`dart:io` exceptions for the screens' connection message.
class AuthApi {
  AuthApi({required String baseUrl, ApiClient? client})
      : _api = client ?? ApiClient(baseUrl: baseUrl);

  final ApiClient _api;

  /// Creates the account and emails a 6-digit code. Returns the seconds
  /// until another code can be requested. No session until [verifyEmail].
  Future<int> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final body = await _post('/api/auth/register', {
      'full_name': fullName,
      'email': email,
      'password': password,
    });
    return body['resend_available_in'] as int? ?? 60;
  }

  /// Confirms the emailed code; signs the new user in.
  Future<AuthSession> verifyEmail({
    required String email,
    required String code,
  }) async =>
      AuthSession.fromJson(
        await _post('/api/auth/verify-email', {'email': email, 'code': code}),
      );

  /// Emails a new code. Returns seconds until the next one can be asked for.
  Future<int> resendVerificationCode(String email) async {
    final body = await _post('/api/auth/resend-code', {'email': email});
    return body['resend_available_in'] as int? ?? 60;
  }

  /// Throws [TwoFactorRequired] when the account needs its emailed code.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final body = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    if (body['two_factor_required'] == true) {
      throw TwoFactorRequired(
        challengeToken: body['challenge_token'] as String,
        email: body['email'] as String? ?? email,
        resendAvailableIn: body['resend_available_in'] as int? ?? 60,
      );
    }
    return AuthSession.fromJson(body);
  }

  /// Finishes a two-factor sign-in with the emailed code.
  Future<AuthSession> verifyTwoFactor({
    required String challengeToken,
    required String code,
  }) async =>
      AuthSession.fromJson(await _post('/api/auth/2fa/verify', {
        'challenge_token': challengeToken,
        'code': code,
      }));

  /// Emails another sign-in code. Returns seconds until the next one.
  Future<int> resendTwoFactor(String challengeToken) async {
    final body = await _post(
      '/api/auth/2fa/resend',
      {'challenge_token': challengeToken},
    );
    return body['resend_available_in'] as int? ?? 60;
  }

  /// Emails the signed-in user a code to confirm turning 2FA on or off.
  /// Returns seconds until another may be requested.
  Future<int> sendTwoFactorCode({required String accessToken}) async {
    final body = await _api.send(
      'POST',
      '/api/auth/2fa/code',
      bearer: accessToken,
    );
    return body['resend_available_in'] as int? ?? 60;
  }

  /// Turns two-factor on or off with the emailed code.
  Future<void> setTwoFactor({
    required String accessToken,
    required String code,
    required bool enabled,
  }) =>
      _api.send(
        'POST',
        enabled ? '/api/auth/2fa/enable' : '/api/auth/2fa/disable',
        json: {'code': code},
        bearer: accessToken,
      );

  /// Exchanges a Google ID token (verified by the server) for a session.
  Future<AuthSession> loginWithGoogle(String idToken) async =>
      AuthSession.fromJson(
        await _post('/api/auth/google', {'id_token': idToken}),
      );

  /// Rotates the refresh token: the one passed in stops working.
  Future<AuthSession> refresh(String refreshToken) async =>
      AuthSession.fromJson(
        await _post('/api/auth/refresh', {'refresh_token': refreshToken}),
      );

  Future<void> logout(String refreshToken) =>
      _post('/api/auth/logout', {'refresh_token': refreshToken});

  /// Emails a password reset code. Returns seconds until another may be
  /// requested. Succeeds for unknown emails too.
  Future<int> forgotPassword(String email) async {
    final body = await _post('/api/auth/forgot-password', {'email': email});
    return body['resend_available_in'] as int? ?? 60;
  }

  /// Sets a new password from the emailed code. Signs out every device and
  /// returns a session for this one.
  Future<AuthSession> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async =>
      AuthSession.fromJson(await _post('/api/auth/reset-password', {
        'email': email,
        'code': code,
        'new_password': newPassword,
      }));

  /// Signs out every other device and returns a new session for this one.
  Future<AuthSession> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async =>
      AuthSession.fromJson(await _api.send(
        'POST',
        '/api/auth/change-password',
        json: {'current_password': currentPassword, 'new_password': newPassword},
        bearer: accessToken,
      ));

  Future<void> deleteAccount({required String accessToken}) =>
      _api.send('DELETE', '/api/users/me', bearer: accessToken);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _api.send('POST', path, json: body, authorized: false);
}
