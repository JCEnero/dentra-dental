import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has finished (or skipped) onboarding, so
/// returning users land directly on the sign-in screen.
///
/// Storage failures never block the user: reads fall back to "not completed"
/// (onboarding is shown again) and writes are best-effort.
abstract class OnboardingStorage {
  // Bump the suffix if the onboarding changes enough that existing users
  // should see it again.
  static const String _completedKey = 'onboarding.completed.v1';

  static Future<bool> isCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_completedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedKey, true);
    } catch (_) {
      // Best-effort: worst case the user sees onboarding once more.
    }
  }
}
