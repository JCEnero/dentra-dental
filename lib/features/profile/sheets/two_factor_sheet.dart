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

/// Opens the two-factor sheet: emails a code and, once it is entered,
/// turns 2FA on ([enable]) or off. Resolves to true once the change is
/// saved.
Future<bool> showTwoFactorSheet(
  BuildContext context, {
  required String email,
  required bool enable,
}) async {
  final changed = await showGlassSheet<bool>(
    context: context,
    title: enable
        ? 'Two-factor authentication'
        : 'Turn off two-factor authentication',
    subtitle: enable
        ? 'Add a second step to sign-in with a code sent to your email.'
        : 'Confirm with a code sent to your email.',
    builder: (_) => _TwoFactorForm(email: email, enable: enable),
  );
  return changed ?? false;
}

class _TwoFactorForm extends ConsumerStatefulWidget {
  const _TwoFactorForm({required this.email, required this.enable});

  final String email;
  final bool enable;

  @override
  ConsumerState<_TwoFactorForm> createState() => _TwoFactorFormState();
}

class _TwoFactorFormState extends ConsumerState<_TwoFactorForm> {
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
        _startCooldown(result.resendAvailableIn ?? 60);
      } else {
        _formError = result.error ?? _connectionError;
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
    // Outlives this sheet, which may be dismissed while the call runs.
    final container = ProviderScope.containerOf(context, listen: false);
    AuthResult result;
    try {
      result = await container
          .read(authServiceProvider)
          .setTwoFactor(code: code, enable: widget.enable);
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (result.success) await _syncProfile(container);
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

  /// Mirrors the change on the profile. The account already changed, so
  /// if saving the mirror fails the profile is reloaded instead.
  Future<void> _syncProfile(ProviderContainer container) async {
    try {
      await container
          .read(profileProvider.notifier)
          .setPreferences(twoFactorEnabled: widget.enable);
    } catch (_) {
      container.invalidate(profileProvider);
    }
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
            onPressed:
                _sending || _verifying || _cooldown > 0 ? null : _sendCode,
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
          label: widget.enable ? 'Verify and turn on' : 'Verify and turn off',
          loadingLabel: 'Verifying…',
          loading: _verifying,
          onPressed: _codeSent ? _verify : null,
        ),
      ],
    );
  }
}
