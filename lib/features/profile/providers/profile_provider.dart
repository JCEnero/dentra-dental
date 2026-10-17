import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_assistant/ai_chat_controller.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../data/models/user_profile.dart';
import '../services/api_profile_service.dart';
import '../services/profile_service.dart';

/// Backend for profile reads and writes. Override in tests.
final profileServiceProvider = Provider<ProfileService>((ref) {
  // The DENTRA API when configured, the on-device store otherwise.
  final api = ref.watch(apiClientProvider);
  return api == null ? LocalProfileService() : ApiProfileService(api);
});

/// The signed-in user's profile. Reloads when the signed-in user changes,
/// so signing out and back in as someone else never shows stale data.
final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  // Used when the app is opened without a session (e.g. during development).
  static const _guestId = 'guest';

  ProfileService get _service => ref.read(profileServiceProvider);
  String _userId = _guestId;

  @override
  Future<UserProfile> build() async {
    _userId = ref.watch(authServiceProvider.select((a) => a.currentUserId)) ??
        _guestId;
    final auth = ref.read(authServiceProvider);

    UserProfile? stored;
    try {
      stored = await _service.fetchProfile(_userId);
    } catch (_) {
      // Unreadable local data should not lock the user out of the page;
      // fall back to what the session knows.
    }

    return stored ??
        UserProfile(
          fullName: auth.currentDisplayName ?? _nameFromEmail(auth.currentEmail),
          email: auth.currentEmail ?? '',
        );
  }

  /// Saves name, contact details, date of birth and gender. Throws
  /// [ProfileException] on failure and leaves the current state untouched.
  Future<void> saveDetails(UserProfile details) async {
    final current = await future;
    final next = current.copyWith(
      fullName: details.fullName,
      email: details.email,
      phone: () => details.phone,
      dateOfBirth: () => details.dateOfBirth,
      gender: () => details.gender,
    );
    final saved = await _service.updateProfile(_userId, next);
    state = AsyncData(saved.copyWith(avatarBytes: () => current.avatarBytes));
    ref
        .read(authServiceProvider)
        .updateIdentity(displayName: saved.fullName, email: saved.email);
  }

  /// Sets the profile photo, or removes it when [bytes] is null.
  Future<void> setAvatar(Uint8List? bytes) async {
    final current = await future;
    await _service.updateAvatar(_userId, bytes);
    state = AsyncData(current.copyWith(avatarBytes: () => bytes));
  }

  /// Updates preferences optimistically so switches respond instantly,
  /// then rolls back and rethrows if the save fails.
  Future<void> setPreferences({
    bool? analyticsConsent,
    bool? marketingConsent,
    bool? twoFactorEnabled,
  }) async {
    final previous = await future;
    final next = previous.copyWith(
      analyticsConsent: analyticsConsent,
      marketingConsent: marketingConsent,
      twoFactorEnabled: twoFactorEnabled,
    );
    state = AsyncData(next);
    try {
      await _service.updateProfile(_userId, next);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Deletes the account on the backend, then this user's local profile
  /// and screening history.
  /// Local data is only removed once the backend confirms, so a failed
  /// request leaves everything as it was.
  Future<AuthResult> deleteAccount() async {
    // Captured first: the session clears during deletion, which resets
    // [_userId] on the next rebuild.
    final userId = _userId;
    final result = await ref.read(authServiceProvider).deleteAccount();
    if (result.success) {
      await _service.deleteProfile(userId);
      // Screening history is keyed by the same user id. On the backend
      // this is an ON DELETE CASCADE from users.
      await ref.read(screeningRepositoryProvider).deleteAll(userId);
      ref.read(screeningImageCacheProvider.notifier).clear();
      ref.invalidate(screeningSessionsProvider);
      try {
        await ref.read(notificationRepositoryProvider).deleteAll(userId);
        await AiChatController.deleteStoredHistory(userId);
      } catch (_) {
        // On the backend this is an ON DELETE CASCADE from users.
      }
      ref.invalidate(notificationsProvider);
    }
    return result;
  }

  /// "ana.cruz@mail.com" -> "Ana Cruz". Empty when there is no email.
  static String _nameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return '';
    return email
        .split('@')
        .first
        .split(RegExp(r'[._\-+]+'))
        .where((p) => p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p))
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(' ');
  }
}
