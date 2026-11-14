import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../auth/services/auth_service.dart';
import '../providers/profile_provider.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';

/// Asks the user to type a confirmation word, then deletes the account
/// and its local data. Resolves to true once the account is gone.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final deleted = await showGlassDialog<bool>(
    context: context,
    // Not dismissible by tapping outside: avoids losing the typed
    // confirmation, and the user must not leave mid-deletion.
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
  return deleted ?? false;
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  static const _confirmWord = 'DELETE';

  final _ctrl = TextEditingController();
  bool _deleting = false;
  String? _error;

  bool get _confirmed => _ctrl.text.trim().toUpperCase() == _confirmWord;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting || !_confirmed) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _deleting = true;
      _error = null;
    });

    AuthResult result;
    try {
      result = await ref.read(profileProvider.notifier).deleteAccount();
    } catch (_) {
      result = const AuthResult(
        success: false,
        error: "We couldn't reach DENTRA. Check your connection and try again.",
      );
    }
    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _deleting = false;
      _error = result.error ?? 'Something went wrong. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: GlassDialogFrame(
        icon: Icons.delete_forever_outlined,
        title: 'Delete account?',
        message: 'This permanently deletes your account, profile and '
            'screening history. It cannot be undone.',
        destructive: true,
        children: [
          Text.rich(
            TextSpan(
              text: 'Type ',
              children: [
                TextSpan(
                  text: _confirmWord,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
                const TextSpan(text: ' to confirm.'),
              ],
            ),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            enabled: !_deleting,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _delete(),
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.navy,
            ),
            decoration: InputDecoration(
              hintText: _confirmWord,
              hintStyle: GoogleFonts.outfit(
                fontSize: 15,
                letterSpacing: 2,
                color: AppColors.secondaryText.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: AppColors.white.withValues(alpha: 0.85),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide(color: AppColors.border),
              ),
              disabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide(color: AppColors.danger, width: 1.5),
              ),
            ),
          ),
          DentraInlineNotice(message: _error),
          const SizedBox(height: 20),
          DentraButtonRow(
            secondary: DentraPillButton(
              label: 'Cancel',
              variant: DentraButtonVariant.outline,
              onPressed:
                  _deleting ? null : () => Navigator.of(context).pop(false),
            ),
            primary: DentraPillButton(
              label: _error != null ? 'Try again' : 'Delete',
              loadingLabel: 'Deleting…',
              variant: DentraButtonVariant.danger,
              loading: _deleting,
              onPressed: _confirmed ? _delete : null,
            ),
          ),
        ],
      ),
    );
  }
}
