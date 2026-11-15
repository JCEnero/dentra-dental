import 'dart:convert';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/auth/services/auth_api.dart';
import 'package:dentra_mobile/features/auth/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = {'id': 'user-1', 'email': 'ana@example.com', 'full_name': 'Ana'};

/// An [AuthService] on a fake backend. Login needs a second step; the
/// code '123456' finishes it. Records each request as (path, body).
(AuthService, List<(String, Map<String, dynamic>)>) _service() {
  final requests = <(String, Map<String, dynamic>)>[];
  final client = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    requests.add((request.url.path, body));
    http.Response json(int status, Object data) => http.Response(
          jsonEncode(data),
          status,
          headers: {'content-type': 'application/json'},
        );
    switch (request.url.path) {
      case '/api/auth/login':
        return json(202, {
          'two_factor_required': true,
          'challenge_token': 'challenge-1',
          'email': 'ana@example.com',
          'resend_available_in': 60,
        });
      case '/api/auth/2fa/verify':
        if (body['code'] != '123456') {
          return json(400, {
            'error': {
              'code': 'invalid_code',
              'message': 'That code is incorrect. 4 tries left.',
            },
          });
        }
        return json(200, {
          'user': _user,
          'access_token': 'access',
          'refresh_token': 'refresh',
          'expires_in': 900,
        });
    }
    return json(404, {});
  });
  final api = ApiClient(baseUrl: 'https://api.test', client: client);
  return (
    AuthService(api: AuthApi(baseUrl: 'https://api.test', client: api)),
    requests,
  );
}

void main() {
  test('a two-factor account is not signed in by the password alone', () async {
    final (auth, _) = _service();
    final result = await auth.signInWithEmail(
      email: 'ana@example.com',
      password: 'correct horse',
    );

    expect(result.success, isFalse);
    expect(result.error, isNull);
    expect(result.needsTwoFactor, isTrue);
    expect(result.twoFactorToken, 'challenge-1');
    expect(result.resendAvailableIn, 60);
    expect(auth.isAuthenticated, isFalse);
  });

  test('the emailed code finishes the sign-in', () async {
    final (auth, requests) = _service();
    final result = await auth.verifyTwoFactorSignIn(
      challengeToken: 'challenge-1',
      code: '123456',
    );

    expect(result.success, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentUserId, 'user-1');
    expect(requests.single.$2,
        {'challenge_token': 'challenge-1', 'code': '123456'});
  });

  test('a wrong code shows the server message and stays signed out', () async {
    final (auth, _) = _service();
    final result = await auth.verifyTwoFactorSignIn(
      challengeToken: 'challenge-1',
      code: '000000',
    );

    expect(result.success, isFalse);
    expect(result.error, 'That code is incorrect. 4 tries left.');
    expect(auth.isAuthenticated, isFalse);
  });
}
