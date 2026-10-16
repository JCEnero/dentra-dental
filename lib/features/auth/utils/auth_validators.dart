/// Field validation shared by the auth screens. Each function returns an
/// error message, or null when the value is valid.
abstract class AuthValidators {
  // Allows sub-domains (name@mail.example.com) and plus-addressing.
  static final _emailPattern =
      RegExp(r'^[\w.+\-]+@[a-zA-Z\d\-]+(\.[a-zA-Z\d\-]+)*\.[a-zA-Z]{2,}$');

  static String? email(String email) {
    if (email.isEmpty) return 'Enter your email address.';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }
}
