import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dental_profile_providers.dart';
import '../screens/dental_questionnaire_screen.dart';

/// Shows [app] only once the server confirms this user has completed
/// dental onboarding, and the questionnaire until then.
///
/// It switches in place rather than navigating, so there is no route to
/// bounce between and no way to reach the app around it: sign-up, sign-in,
/// a restored session and '/home' all arrive here via `SignedInGate`.
class DentalOnboardingGate extends ConsumerWidget {
  const DentalOnboardingGate({super.key, required this.app});

  final Widget app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId =
        ref.watch(authServiceProvider.select((a) => a.currentUserId));
    final status = ref.watch(onboardingStatusProvider);

    final (String, Widget) view = switch (status) {
      AsyncData(:final value) => _forStatus(value, userId),
      AsyncError() when !status.isLoading => (
          'error',
          _StatusError(
            onRetry: () => ref.invalidate(onboardingStatusProvider),
            onSignOut: () => ref.read(authServiceProvider).signOut(),
          ),
        ),
      // Refreshing: keep what is on screen.
      _ when status.hasValue => _forStatus(status.requireValue, userId),
      _ => ('loading', const _StatusLoading()),
    };

    return AnimatedSwitcher(
      duration: dentraMotion(context, 260),
      child: KeyedSubtree(key: ValueKey(view.$1), child: view.$2),
    );
  }

  (String, Widget) _forStatus(bool completed, String? userId) => completed
      ? ('app', app)
      // Keyed by user so a different account never sees another's draft.
      : (
          'questionnaire-$userId',
          DentalQuestionnaireScreen.onboarding(key: ValueKey(userId)),
        );
}

class _StatusLoading extends StatelessWidget {
  const _StatusLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: Center(
          child: Semantics(
            label: 'Loading your profile',
            child: const CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

/// The status couldn't be loaded (usually offline). Nothing is assumed:
/// the user retries, or signs out.
class _StatusError extends StatelessWidget {
  const _StatusError({required this.onRetry, required this.onSignOut});

  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 40, color: AppColors.secondaryText),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        "We couldn't load your profile",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 22),
                    DentraPillButton(label: 'Try again', onPressed: onRetry),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onSignOut,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondaryText,
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text(
                        'Sign out',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
