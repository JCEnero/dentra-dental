import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/profile_provider.dart';
import '../utils/device_settings.dart';
import '../widgets/profile_settings.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';

Future<void> showPrivacyConsentSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    title: 'Privacy & consent',
    subtitle: 'Choose how DENTRA may use your data. Changes save right away.',
    builder: (_) => const _PrivacyConsentBody(),
  );
}

enum _Consent { analytics, marketing }

class _PrivacyConsentBody extends ConsumerStatefulWidget {
  const _PrivacyConsentBody();

  @override
  ConsumerState<_PrivacyConsentBody> createState() =>
      _PrivacyConsentBodyState();
}

class _PrivacyConsentBodyState extends ConsumerState<_PrivacyConsentBody> {
  final _saving = <_Consent>{};
  String? _error;
  _Consent? _failed;
  bool? _failedValue;
  String? _settingsError;

  Future<void> _openSettings() async {
    final opened = await openDeviceSettings(context, notify: false);
    if (mounted) {
      setState(() => _settingsError = opened ? null : deviceSettingsUnavailable);
    }
  }

  Future<void> _set(_Consent consent, bool value) async {
    if (_saving.contains(consent)) return;
    setState(() {
      _saving.add(consent);
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).setPreferences(
            analyticsConsent: consent == _Consent.analytics ? value : null,
            marketingConsent: consent == _Consent.marketing ? value : null,
          );
    } catch (_) {
      // The notifier has already rolled the switch back.
      if (mounted) {
        setState(() {
          _error = "We couldn't save that change. Your previous setting is kept.";
          _failed = consent;
          _failedValue = value;
        });
      }
    } finally {
      if (mounted) setState(() => _saving.remove(consent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    if (profile == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSheetCard(
          children: [
            ProfileSwitchTile(
              icon: Icons.insights_outlined,
              title: 'Usage analytics',
              subtitle: 'Share anonymous usage data to help improve DENTRA.',
              value: profile.analyticsConsent,
              busy: _saving.contains(_Consent.analytics),
              onChanged: (v) => _set(_Consent.analytics, v),
            ),
            ProfileSwitchTile(
              icon: Icons.mark_email_unread_outlined,
              title: 'Tips and updates by email',
              subtitle: 'Occasional oral-care tips and product news.',
              value: profile.marketingConsent,
              busy: _saving.contains(_Consent.marketing),
              onChanged: (v) => _set(_Consent.marketing, v),
            ),
          ],
        ),
        DentraInlineNotice(message: _error),
        if (_error != null && _failed != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _set(_failed!, _failedValue!),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.g2,
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                'Try again',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        const SizedBox(height: 22),
        Text(
          'DEVICE PERMISSIONS',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 10),
        ProfileSheetCard(
          children: [
            ProfileSettingsTile(
              icon: Icons.tune_rounded,
              title: 'Camera, photos and location',
              subtitle: 'Managed by your device. Camera is needed for '
                  'screenings, location for finding nearby clinics.',
              onTap: _openSettings,
              trailing: const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        DentraInlineNotice(message: _settingsError),
      ],
    );
  }
}
