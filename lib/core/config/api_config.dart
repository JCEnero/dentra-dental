import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Backend settings read from the bundled `.env`.
///
///   API_BASE_URL             e.g. http://10.0.2.2:4000 (Android emulator)
///   GOOGLE_SERVER_CLIENT_ID  the *Web application* OAuth client ID
///
/// Both are optional. Without API_BASE_URL the app runs on the built-in
/// demo auth (also what widget tests use, since they never load `.env`).
abstract final class ApiConfig {
  /// Forces demo mode (no backend calls). Keep false so sign-in is
  /// checked against the backend.
  static const bool forceOfflineDemo = false;

  static String? get baseUrl => forceOfflineDemo
      ? null
      : _read('API_BASE_URL')?.replaceFirst(
          RegExp(r'/+$'),
          '',
        );

  static String? get googleServerClientId => _read('GOOGLE_SERVER_CLIENT_ID');

  static String? _read(String key) {
    if (!dotenv.isInitialized) return null;
    final value = dotenv.maybeGet(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
