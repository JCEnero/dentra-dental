import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../providers/profile_provider.dart';
import '../utils/profile_validators.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';

/// Two steps: type a confirmation word, then enter the code emailed to the
/// account. Only then are the account and its local data deleted.
/// Resolves to true once the account is gone.
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
  static const _connectionError =
      "We couldn't reach DENTRA. Check your connection and try again.";

  final _wordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  /// False while typing the confirmation word, true on the code step.
  bool _codeStep = false;
  bool _sending = false;
  bool _codeSent = false;
  bool _deleting = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  bool get _confirmed => _wordCtrl.text.trim().toUpperCase() == _confirmWord;
  bool get _busy => _sending || _deleting;

  @override
  void dispose() {
    _timer?.cancel();
    _wordCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_confirmed) return;
    FocusScope.of(context).unfocus();
    setState(() => _codeStep = true);
    _sendCode();
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    AuthResult result;
    try {
      result = await ref.read(authServiceProvider).sendDeleteAccountCode();
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.success) {
        _codeSent = true;
        _startCooldown(result.resendAvailableIn ?? 60);
      } else {
        _error = result.error ?? _connectionError;
      }
    });
    if (result.success) _codeFocus.requestFocus();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    _cooldown = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _delete() async {
    if (_deleting || !_codeSent) return;
    final code = _codeCtrl.text.trim();
    final invalid = ProfileValidators.otpCode(code);
    if (invalid != null) {
      setState(() => _error = invalid);
      _codeFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _deleting = true;
      _error = null;
    });

    AuthResult result;
    try {
      result =
          await ref.read(profileProvider.notifier).deleteAccount(code: code);
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
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
    _codeFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authServiceProvider).currentEmail;
    final to = email == null || email.isEmpty ? 'your email' : email;

    return PopScope(
      canPop: !_deleting,
      child: GlassDialogFrame(
        icon: _codeStep
            ? Icons.mark_email_read_outlined
            : Icons.delete_forever_outlined,
        title: _codeStep ? 'Confirm with a code' : 'Delete account?',
        message: _codeStep
            ? (_sending && !_codeSent
                ? 'Sending a code to $to…'
                : _codeSent
                    ? 'Enter the 6-digit code we sent to $to.'
                    : "We couldn't send your code.")
            : 'This permanently deletes your account, profile and '
                'screening history. It cannot be undone.',
        destructive: true,
        children: _codeStep ? _codeChildren() : _wordChildren(),
      ),
    );
  }

  List<Widget> _wordChildren() => [
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
          controller: _wordCtrl,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _continue(),
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.navy,
          ),
          decoration: _fieldDecoration(
            hint: _confirmWord,
            hintStyle: GoogleFonts.outfit(
              fontSize: 15,
              letterSpacing: 2,
              color: AppColors.secondaryText.withValues(alpha: 0.4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),
        DentraButtonRow(
          secondary: DentraPillButton(
            label: 'Cancel',
            variant: DentraButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          primary: DentraPillButton(
            label: 'Continue',
            variant: DentraButtonVariant.danger,
            onPressed: _confirmed ? _continue : null,
          ),
        ),
      ];

  List<Widget> _codeChildren() => [
        Semantics(
          label: 'Verification code',
          textField: true,
          child: TextField(
            controller: _codeCtrl,
            focusNode: _codeFocus,
            enabled: _codeSent && !_deleting,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            // No auto-submit at 6 digits: deleting is final, so it waits
            // for a deliberate tap.
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _delete(),
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 10,
              color: AppColors.navy,
            ),
            decoration: _fieldDecoration(
              hint: '000000',
              hintStyle: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: 10,
                color: AppColors.secondaryText.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        DentraInlineNotice(message: _error),
        Center(
          child: TextButton(
            onPressed: _busy || _cooldown > 0 ? null : _sendCode,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.g2,
              minimumSize: const Size(44, 44),
            ),
            child: Text(
              _sending
                  ? 'Sending…'
                  : _cooldown > 0
                      ? 'Resend code in ${_cooldown}s'
                      : (_codeSent ? 'Resend code' : 'Try again'),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        DentraButtonRow(
          secondary: DentraPillButton(
            label: 'Cancel',
            variant: DentraButtonVariant.outline,
            onPressed:
                _deleting ? null : () => Navigator.of(context).pop(false),
          ),
          primary: DentraPillButton(
            label: 'Delete',
            loadingLabel: 'Deleting…',
            variant: DentraButtonVariant.danger,
            loading: _deleting,
            onPressed: _codeSent ? _delete : null,
          ),
        ),
      ];

  InputDecoration _fieldDecoration({
    required String hint,
    required TextStyle hintStyle,
    required EdgeInsets padding,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: hintStyle,
        filled: true,
        fillColor: AppColors.white.withValues(alpha: 0.85),
        contentPadding: padding,
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide:
              BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      );
}
