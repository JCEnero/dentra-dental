import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/services/auth_service.dart';

abstract interface class DeletionOtpRepository {
  Future<AuthResult> sendDeletionOtp();
  Future<AuthResult> confirmDeletionOtp(String code);
}

/// Offline UI implementation. Use code 123456 in demo mode.
class MockDeletionOtpRepository implements DeletionOtpRepository {
  bool _sent = false;

  @override
  Future<AuthResult> sendDeletionOtp() async {
    _sent = true;
    return const AuthResult(success: true);
  }

  @override
  Future<AuthResult> confirmDeletionOtp(String code) async =>
      _sent && code.trim() == '123456'
      ? const AuthResult(success: true)
      : const AuthResult(
          success: false,
          error: 'Enter the valid 6-digit code.',
        );
}

final deletionOtpRepositoryProvider = Provider<DeletionOtpRepository>(
  (ref) => MockDeletionOtpRepository(),
);
