import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/api_dental_profile_repository.dart';
import '../data/dental_profile_repository.dart';
import '../data/models/dental_answers.dart';
import '../data/questionnaire_draft_store.dart';

/// Backend for the dental profile: the DENTRA API when configured, the
/// on-device demo store otherwise. Override in tests.
final dentalProfileRepositoryProvider = Provider<DentalProfileRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return api == null
      ? LocalDentalProfileRepository()
      : ApiDentalProfileRepository(api);
});

/// Unsubmitted questionnaire drafts. Override in tests.
final questionnaireDraftStoreProvider =
    Provider<QuestionnaireDraftStore>((ref) => SecureQuestionnaireDraftStore());

/// Whether the signed-in user has completed dental onboarding, as stored
/// on the server. Re-checked whenever the signed-in user changes (sign-in,
/// sign-up, session restore, sign-out).
final onboardingStatusProvider =
    AsyncNotifierProvider<OnboardingStatusNotifier, bool>(
  OnboardingStatusNotifier.new,
);

class OnboardingStatusNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final userId =
        ref.watch(authServiceProvider.select((a) => a.currentUserId));
    if (userId == null) return false;

    try {
      final completed = await ref
          .read(dentalProfileRepositoryProvider)
          .fetchOnboardingCompleted(userId);
      unawaited(OnboardingCompletionCache.write(userId, completed));
      return completed;
    } on DentalProfileException catch (e) {
      // Offline: a user the server already confirmed goes straight in.
      // Everyone else waits for the server (see the gate's retry).
      if (e.offline && await OnboardingCompletionCache.read(userId)) {
        return true;
      }
      rethrow;
    }
  }

  /// Records completion. Only call once the server has confirmed the save.
  void markCompleted(String userId) {
    state = const AsyncData(true);
    unawaited(OnboardingCompletionCache.write(userId, true));
  }
}

/// The signed-in user's saved dental profile, or null before onboarding.
/// Reloads when the signed-in user changes.
final dentalProfileProvider =
    AsyncNotifierProvider<DentalProfileNotifier, DentalProfile?>(
  DentalProfileNotifier.new,
);

class DentalProfileNotifier extends AsyncNotifier<DentalProfile?> {
  DentalProfileRepository get _repo =>
      ref.read(dentalProfileRepositoryProvider);

  @override
  Future<DentalProfile?> build() async {
    final userId =
        ref.watch(authServiceProvider.select((a) => a.currentUserId));
    if (userId == null) return null;
    return _repo.fetchProfile(userId);
  }

  /// Saves the questionnaire: the first submission when [update] is
  /// false, changes to an existing profile otherwise.
  ///
  /// State changes only after the server confirms the save, so a failure
  /// (thrown as [DentalProfileException]) never marks onboarding as
  /// completed and leaves the stored profile as it was.
  Future<DentalProfile> save(DentalAnswers answers, {bool update = false}) async {
    final userId = ref.read(authServiceProvider).currentUserId;
    if (userId == null) {
      throw const DentalProfileException(
        'Your session has ended. Please sign in again.',
        sessionEnded: true,
      );
    }

    final saved = update
        ? await _repo.updateProfile(userId, answers)
        : await _repo.submitProfile(userId, answers);

    state = AsyncData(saved);
    // Saved is saved: tidying up the draft never holds the user here.
    unawaited(ref.read(questionnaireDraftStoreProvider).clear(userId));
    ref.read(onboardingStatusProvider.notifier).markCompleted(userId);
    return saved;
  }
}
