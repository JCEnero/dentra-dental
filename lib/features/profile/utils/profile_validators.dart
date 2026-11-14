import '../../auth/utils/auth_validators.dart';

/// Field validation for the profile and security forms. Each function
/// returns an error message, or null when the value is valid.
abstract class ProfileValidators {
  // Letters from any script, plus spaces, apostrophes, periods and hyphens
  // ("María-José O'Neil Jr.").
  static final _namePattern = RegExp(r"^[\p{L}\p{M}' .\-]+$", unicode: true);

  // Digits with optional leading +, spaces, dashes, dots and parentheses.
  static final _phonePattern = RegExp(r'^\+?[\d\s\-().]+$');

  static String? fullName(String value) {
    if (value.isEmpty) return 'Enter your full name.';
    if (value.length < 2) return 'Name must be at least 2 characters.';
    if (value.length > 60) return 'Name must be 60 characters or fewer.';
    if (!_namePattern.hasMatch(value)) {
      return 'Use letters, spaces, hyphens or apostrophes only.';
    }
    return null;
  }

  static String? email(String value) => AuthValidators.email(value);

  /// Optional: empty is valid.
  static String? phone(String value) {
    if (value.isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (!_phonePattern.hasMatch(value) ||
        digits.length < 7 ||
        digits.length > 15) {
      return 'Enter a valid phone number, e.g. +63 912 345 6789.';
    }
    return null;
  }

  /// Optional: null is valid.
  static String? dateOfBirth(DateTime? value, {DateTime? now}) {
    if (value == null) return null;
    final today = now ?? DateTime.now();
    if (value.isAfter(today)) return 'Date of birth cannot be in the future.';
    if (today.year - value.year > 120) return 'Enter a valid date of birth.';
    return null;
  }

  // ── Passwords ─────────────────────────────────────────────────

  static String? currentPassword(String value) =>
      value.isEmpty ? 'Enter your current password.' : null;

  static String? newPassword(String value, {required String current}) {
    if (value.isEmpty) return 'Create a new password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'\d').hasMatch(value)) return 'Include at least one number.';
    if (!RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value)) {
      return 'Mix uppercase and lowercase letters.';
    }
    if (current.isNotEmpty && value == current) {
      return 'Choose a password different from your current one.';
    }
    return null;
  }

  static String? confirmPassword(String value, {required String newPassword}) {
    if (value.isEmpty) return 'Re-enter your new password.';
    if (value != newPassword) return "Passwords don't match.";
    return null;
  }

  static String? otpCode(String value) {
    if (value.isEmpty) return 'Enter the 6-digit code.';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'The code is 6 digits.';
    }
    return null;
  }
}
