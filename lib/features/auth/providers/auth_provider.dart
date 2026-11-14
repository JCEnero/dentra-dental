import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../services/auth_service.dart';

/// App-wide auth session shared by the sign-in and sign-up screens.
/// Uses the backend from `.env` when configured, demo auth otherwise.
/// The launch loader (`SessionLoader`) restores a stored session into it.
/// Riverpod disposes the service with the ProviderScope.
final authServiceProvider =
    ChangeNotifierProvider<AuthService>((ref) => AuthService.fromEnvironment());

/// Client for the signed-in user's API calls (profile, screenings,
/// notifications). Null without a backend: features then use their
/// on-device stores.
final apiClientProvider = Provider<ApiClient?>((ref) {
  final baseUrl = ApiConfig.baseUrl;
  if (baseUrl == null) return null;
  return ApiClient(
    baseUrl: baseUrl,
    // Read lazily so it always uses the current session.
    accessToken: () => ref.read(authServiceProvider).validAccessToken(),
  );
});
