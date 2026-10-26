import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, per account, whether the app tour was finished or skipped,
/// so it only greets each user once on this device.
///
/// Storage failures never block the user: reads fall back to "not
/// completed" (the tour shows again) and writes are best-effort.
abstract class AppTourStorage {
  // Bump the version if the tour changes enough that existing users
  // should see it again.
  static String _key(String? userId) =>
      'app_tour.completed.v1.${userId ?? 'guest'}';

  static Future<bool> isCompleted(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markCompleted(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(userId), true);
    } catch (_) {
      // Best-effort: worst case the user sees the tour once more.
    }
  }
}
