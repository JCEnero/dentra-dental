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

/// Opens the two-factor setup sheet. Resolves to true once 2FA is on and
/// saved to the profile.
Future<bool> showTwoFactorSetupSheet(
  BuildContext context, {
  required String email,
}) async {
  final enabled = await showGlassSheet<bool>(
    context: context,
    title: 'Two-factor authentication',
    subtitle: 'Add a second step to sign-in with a code sent to your email.',
    builder: (_) => _TwoFactorForm(email: email),
  );
  return enabled ?? false;
}

class _TwoFactorForm extends ConsumerStatefulWidget {
  const _TwoFactorForm({required this.email});

  final String email;

  @override
  ConsumerState<_TwoFactorForm> createState() => _TwoFactorFormState();
}

class _TwoFactorFormState extends ConsumerState<_TwoFactorForm> {
  static const _resendCooldown = 30;
  static const _connectionError =
      "We couldn't reach DENTRA. Check your connection and try again.";

  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  bool _sending = true;
  bool _codeSent = false;
  bool _verifying = false;
  String? _codeError;
  String? _formError;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _formError = null;
    });
    AuthResult result;
    try {
      result = await ref.read(authServiceProvider).sendTwoFactorCode();
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.success) {
        _codeSent = true;
        _startCooldown();
      } else {
        _formError = result.error ?? _connectionError;
      }
    });
    if (result.success) _codeFocus.requestFocus();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = _resendCooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_verifying || !_codeSent) return;
    final code = _codeCtrl.text.trim();
    final error = ProfileValidators.otpCode(code);
    setState(() {
      _codeError = error;
      _formError = null;
    });
    if (error != null) {
      _codeFocus.requestFocus();
      return;
    }

    setState(() => _verifying = true);
    AuthResult result;
    try {
      result = await ref.read(authServiceProvider).enableTwoFactor(code: code);
      if (result.success) {
        await ref
            .read(profileProvider.notifier)
            .setPreferences(twoFactorEnabled: true);
      }
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _verifying = false;
      _codeError = result.error;
    });
    _codeFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _codeError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: dentraMotion(context),
          child: Text(
            _sending && !_codeSent
                ? 'Sending a code to ${widget.email}…'
                : _codeSent
                    ? 'Enter the 6-digit code we sent to ${widget.email}.'
                    : "We couldn't send your code.",
            key: ValueKey('$_sending$_codeSent'),
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.navy,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Semantics(
          label: 'Verification code',
          textField: true,
          child: TextField(
            controller: _codeCtrl,
            focusNode: _codeFocus,
            enabled: _codeSent && !_verifying,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
              if (_codeCtrl.text.length == 6) _verify();
            },
            onSubmitted: (_) => _verify(),
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              letterSpacing: 12,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText.withValues(alpha: 0.3),
                letterSpacing: 12,
              ),
              filled: true,
              fillColor: hasError
                  ? const Color(0xFFFFF5F3)
                  : AppColors.white.withValues(alpha: 0.8),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.lgAll,
                borderSide: BorderSide(
                  color: hasError
                      ? AppColors.coral.withValues(alpha: 0.6)
                      : AppColors.border,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.lgAll,
                borderSide: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.lgAll,
                borderSide: BorderSide(
                  color: hasError ? AppColors.coral : AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        DentraInlineNotice(message: _codeError ?? _formError),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _sending || _verifying || _cooldown > 0 ? null : _sendCode,
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
        const SizedBox(height: 14),
        DentraPillButton(
          label: 'Verify and turn on',
          loadingLabel: 'Verifying…',
          loading: _verifying,
          onPressed: _codeSent ? _verify : null,
        ),
      ],
    );
  }
}
