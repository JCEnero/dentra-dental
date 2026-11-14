import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../app_tour/providers/app_tour_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camera/camera_flow.dart';
import '../../camera/camera_strings.dart';
import '../../camera/providers/camera_providers.dart';
import '../../dental_profile/data/dental_profile_repository.dart';
import '../../dental_profile/data/models/dental_answers.dart';
import '../../dental_profile/providers/dental_profile_providers.dart';
import '../../dental_profile/screens/dental_questionnaire_screen.dart';
import '../../notifications/data/models/app_notification.dart';
import '../../notifications/data/notification_events.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../data/models/user_profile.dart';
import '../data/profile_content.dart';
import '../providers/profile_provider.dart';
import '../services/profile_service.dart';
import '../sheets/change_password_sheet.dart';
import '../sheets/delete_account_dialog.dart';
import '../sheets/help_support_sheet.dart';
import '../sheets/info_sheets.dart';
import '../sheets/privacy_consent_sheet.dart';
import '../sheets/two_factor_sheet.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/profile_settings.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import 'edit_profile_screen.dart';

/// Profile tab: identity, account and security settings, support and
/// sign-out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.onNavigate});

  /// Switches the app shell's tab (used to open Screening History).
  final ValueChanged<int>? onNavigate;

  /// Index of the History tab in `AppShell`.
  static const historyTab = 2;

  /// Index of the Scan tab in `AppShell`.
  static const scanTab = 1;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _avatarBusy = false;
  bool _twoFactorBusy = false;
  bool _signingOut = false;
  bool _dentalProfileBusy = false;

  /// Records an account or security event in the notification center.
  void _notify(AppNotification notification) {
    if (!mounted) return;
    ref.read(notificationsProvider.notifier).record(notification);
  }

  // ── Profile ───────────────────────────────────────────────────

  Future<void> _editProfile(UserProfile profile) async {
    final saved = await Navigator.of(context, rootNavigator: true)
        .push(EditProfileScreen.route(profile));
    if (saved == true) _notify(NotificationEvents.profileUpdated());
    if (saved == true && mounted) {
      showDentraSnack(context, 'Profile updated.');
    }
  }

  Future<void> _changeAvatar(UserProfile profile) async {
    if (_avatarBusy) return;
    final choice =
        await chooseAvatar(context, hasPhoto: profile.avatarBytes != null);
    if (choice == null || !mounted) return;
    await _applyAvatar(choice);
  }

  Future<void> _applyAvatar(AvatarChoice choice) async {
    setState(() => _avatarBusy = true);
    final bytes = switch (choice) {
      AvatarPicked(:final bytes) => bytes,
      AvatarRemoved() => null,
    };
    try {
      await ref.read(profileProvider.notifier).setAvatar(bytes);
      if (mounted) {
        showDentraSnack(
          context,
          bytes == null ? 'Profile photo removed.' : 'Profile photo updated.',
        );
      }
    } catch (e) {
      if (mounted) {
        showDentraSnack(
          context,
          e is ProfileException ? e.message : "Couldn't update your photo.",
          tone: DentraFeedbackTone.error,
          onRetry: () => _applyAvatar(choice),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  /// Opens the saved questionnaire answers for review and editing,
  /// loading the latest copy from the server first.
  Future<void> _editDentalProfile() async {
    if (_dentalProfileBusy) return;
    setState(() => _dentalProfileBusy = true);
    DentalProfile? profile;
    String? error;
    try {
      profile = await ref.refresh(dentalProfileProvider.future);
    } on DentalProfileException catch (e) {
      error = e.message;
    } catch (_) {
      error = "Couldn't open your dental profile. Please try again.";
    }
    if (!mounted) return;
    setState(() => _dentalProfileBusy = false);
    if (profile == null) {
      showDentraSnack(
        context,
        error ?? "Your dental profile isn't set up yet.",
        tone: DentraFeedbackTone.error,
        onRetry: _editDentalProfile,
      );
      return;
    }

    final saved = await Navigator.of(context, rootNavigator: true)
        .push(DentalQuestionnaireScreen.editRoute(profile));
    if (saved == true && mounted) {
      showDentraSnack(context, 'Dental profile updated.');
    }
  }

  // ── Security ──────────────────────────────────────────────────

  Future<void> _changePassword(UserProfile profile) async {
    final changed =
        await showChangePasswordSheet(context, email: profile.email);
    if (changed) _notify(NotificationEvents.passwordChanged());
    if (changed && mounted) showDentraSnack(context, 'Password updated.');
  }

  Future<void> _toggleTwoFactor(UserProfile profile, bool enable) async {
    if (_twoFactorBusy) return;

    if (enable) {
      if (profile.email.isEmpty) {
        showDentraSnack(
          context,
          'Add an email address to your profile first.',
          tone: DentraFeedbackTone.info,
        );
        return;
      }
    } else {
      final confirmed = await showGlassConfirmDialog(
        context: context,
        icon: Icons.shield_outlined,
        title: 'Turn off two-factor authentication?',
        message: 'Signing in will only need your password. Your account will '
            'be less protected.',
        confirmLabel: 'Turn off',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _twoFactorBusy = true);
    final changed = await showTwoFactorSheet(
      context,
      email: profile.email,
      enable: enable,
    );
    if (!mounted) return;
    setState(() => _twoFactorBusy = false);
    if (!changed) return;
    _notify(NotificationEvents.twoFactorChanged(enabled: enable));
    showDentraSnack(
      context,
      enable
          ? 'Two-factor authentication is on.'
          : 'Two-factor authentication is off.',
    );
  }

  // ── Session ───────────────────────────────────────────────────

  Future<void> _logOut() async {
    if (_signingOut) return;
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.logout_rounded,
      title: 'Log out?',
      message: 'You will need to sign in again to see your profile and '
          'screening history.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {
      // Signing out locally must always succeed; the session state is
      // already cleared by the service even if a remote call fails.
    }
    if (!mounted) return;
    _goToSignIn("You've been logged out.");
  }

  Future<void> _deleteAccount() async {
    final deleted = await showDeleteAccountDialog(context);
    if (deleted && mounted) _goToSignIn('Your account has been deleted.');
  }

  /// Closes everything above the root screen. The session has ended, so
  /// the root's [SignedInGate] already shows sign-in there: one login
  /// screen, with nothing from the old session reachable behind it.
  void _goToSignIn(String message) {
    final toast = DentraToast.of(context);
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
    toast.show(message, tone: DentraFeedbackTone.info);
  }

  // ── Dentra Cam ────────────────────────────────────────────────

  /// Runs the setup guide again, e.g. after a new router. "Start capturing"
  /// at the end goes to the Scan tab and starts a scan there.
  Future<void> _setUpCamera() async {
    final outcome = await openCameraSetup(context);
    if (!mounted || outcome != SetupOutcome.startCapturing) return;
    widget.onNavigate?.call(ProfileScreen.scanTab);
    ref.read(scanStartRequestProvider.notifier).request();
  }

  Widget _cameraSettings() {
    final camera = ref.watch(savedCameraProvider).valueOrNull;
    return ProfileSettingsGroup(
      title: CamText.settingsGroup,
      children: [
        ProfileSettingsTile(
          icon: Icons.videocam_outlined,
          title: CamText.settingsSetupAgain,
          subtitle: camera == null
              ? CamText.settingsNone
              : CamText.settingsSaved(camera.name, camera.ssid),
          onTap: _setUpCamera,
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DentraPageHeader(title: 'Profile'),
          Divider(height: 1, thickness: 1, color: AppGlass.divider),
          Expanded(
            child: AnimatedSwitcher(
              duration: dentraMotion(context, 260),
              child: switch (profileAsync) {
                AsyncData(:final value) => _buildContent(value),
                AsyncError() when !profileAsync.hasValue => _ErrorState(
                    key: const ValueKey('error'),
                    onRetry: () => ref.invalidate(profileProvider),
                  ),
                _ when profileAsync.hasValue =>
                  _buildContent(profileAsync.requireValue),
                _ => const Center(
                    key: ValueKey('loading'),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(UserProfile profile) {
    final sessions = ref.watch(screeningSessionsProvider);
    final list = sessions.valueOrNull;

    return SingleChildScrollView(
      key: const ValueKey('content'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 20, AppSpacing.screenH, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileHeaderCard(
                profile: profile,
                avatarBusy: _avatarBusy,
                screeningCount: list?.length,
                lastScreening: list?.firstOrNull?.completedAt,
                onAvatarTap: () => _changeAvatar(profile),
                onEdit: () => _editProfile(profile),
                onViewHistory: () =>
                    widget.onNavigate?.call(ProfileScreen.historyTab),
              ),
              const SizedBox(height: 28),
              ProfileSettingsGroup(
                title: 'Account',
                children: [
                  ProfileSettingsTile(
                    icon: Icons.badge_outlined,
                    title: 'Personal information',
                    subtitle: 'Name, email, phone and birthday',
                    onTap: () => _editProfile(profile),
                  ),
                  ProfileSettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change password',
                    subtitle: 'Update the password you sign in with',
                    onTap: () => _changePassword(profile),
                  ),
                  ProfileSwitchTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Two-factor authentication',
                    subtitle: profile.twoFactorEnabled
                        ? 'On · Codes sent to your email'
                        : 'Off · Add a code step at sign-in',
                    value: profile.twoFactorEnabled,
                    busy: _twoFactorBusy,
                    onChanged: (v) => _toggleTwoFactor(profile, v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ProfileSettingsGroup(
                title: 'Data & privacy',
                children: [
                  ProfileSettingsTile(
                    icon: Icons.medical_information_outlined,
                    title: 'Dental profile',
                    subtitle: 'Dental history, concerns and screening goals',
                    trailing: _dentalProfileBusy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                    onTap: _editDentalProfile,
                  ),
                  ProfileSettingsTile(
                    icon: Icons.history_rounded,
                    title: 'Screening history',
                    subtitle: 'Review your past screenings',
                    onTap: () =>
                        widget.onNavigate?.call(ProfileScreen.historyTab),
                  ),
                  ProfileSettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & consent',
                    subtitle: 'Analytics, emails and device permissions',
                    onTap: () => showPrivacyConsentSheet(context),
                  ),
                  ProfileSettingsTile(
                    icon: Icons.description_outlined,
                    title: 'Privacy policy',
                    onTap: () => showPrivacyPolicySheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (ref.watch(dentraCamAvailableProvider)) ...[
                _cameraSettings(),
                const SizedBox(height: 24),
              ],
              ProfileSettingsGroup(
                title: 'Support',
                children: [
                  ProfileSettingsTile(
                    icon: Icons.support_agent_rounded,
                    title: 'Help & support',
                    subtitle: 'FAQs, contact us, report a problem',
                    onTap: () => showHelpSupportSheet(context),
                  ),
                  ProfileSettingsTile(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'View introduction',
                    subtitle: 'Replay the welcome tour',
                    onTap: () => Navigator.of(context, rootNavigator: true)
                        .push(OnboardingScreen.replayRoute()),
                  ),
                  ProfileSettingsTile(
                    icon: Icons.explore_outlined,
                    title: 'Take the app tour',
                    subtitle: 'A quick look at where everything lives',
                    onTap: () => ref.read(appTourProvider.notifier).replay(),
                  ),
                  ProfileSettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About DENTRA',
                    subtitle: 'Version ${ProfileContent.appVersion}',
                    onTap: () => showAboutSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _LogOutButton(loading: _signingOut, onPressed: _logOut),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _signingOut ? null : _deleteAccount,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    'Delete account',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width glass button for signing out.
class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: loading ? 'Logging out' : 'Log out',
      excludeSemantics: true,
      child: GlassCard(
        borderRadius: BorderRadius.circular(18),
        borderColor: AppColors.danger.withValues(alpha: 0.25),
        onTap: loading ? null : onPressed,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.danger,
                  ),
                )
              else
                const Icon(Icons.logout_rounded,
                    size: 20, color: AppColors.danger),
              const SizedBox(width: 10),
              Text(
                loading ? 'Logging out…' : 'Log out',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ProfileIconTile(
                  icon: Icons.cloud_off_rounded,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 14),
                Text(
                  "We couldn't load your profile",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
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
                const SizedBox(height: 20),
                DentraPillButton(label: 'Try again', onPressed: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
