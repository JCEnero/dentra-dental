import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../services/app_tour_storage.dart';

/// Whether the app tour is on screen. Resets when the account changes,
/// so one user's tour never carries over to the next.
final appTourProvider =
    NotifierProvider<AppTourController, bool>(AppTourController.new);

class AppTourController extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(authServiceProvider.select((a) => a.currentUserId));
    return false;
  }

  String? get _userId => ref.read(authServiceProvider).currentUserId;

  /// Shows the tour if this account hasn't finished or skipped it yet.
  Future<void> startIfNew() async {
    final userId = _userId;
    if (await AppTourStorage.isCompleted(userId)) return;
    // Signed out or switched account while reading: not theirs to see.
    if (_userId != userId) return;
    state = true;
  }

  /// Shows the tour again on request (Profile → Take the app tour).
  void replay() => state = true;

  /// Hides the tour and remembers it, whether finished or skipped.
  void finish() {
    if (!state) return;
    state = false;
    AppTourStorage.markCompleted(_userId);
  }
}
