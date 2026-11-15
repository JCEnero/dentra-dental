import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

/// Second step of "Forgot password?": the 6-digit code from the email plus
/// a new password. Success signs the user in and signs out other devices.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    this.resendAvailableIn = 60,
  });

  final String email;

  /// Seconds until the user may ask for another code.
  final int resendAvailableIn;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

enum _Field { code, password, confirm }

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const _codeLength = 6;
  static const _connectionError =
      "We couldn't reach Dentra. Check your connection and try again.";

  final _controllers = {
    for (final f in _Field.values) f: TextEditingController()
  };
  final _focusNodes = {for (final f in _Field.values) f: FocusNode()};
  final _errors = <_Field, String?>{};
  AuthService get _authService => ref.read(authServiceProvider);

  bool _saving = false;
  bool _resending = false;
  String? _globalError;
  String? _notice;

  late int _cooldown = widget.resendAvailableIn;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown(widget.resendAvailableIn);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  String _text(_Field f) => _controllers[f]!.text;

  void _startCooldown(int seconds) {
    _timer?.cancel();
    _cooldown = seconds;
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  String? _validate(_Field f) {
    final value = _text(f);
    return switch (f) {
      _Field.code =>
        value.length != _codeLength ? 'Enter the 6-digit code.' : null,
      _Field.password => value.isEmpty
          ? 'Create a new password.'
          : value.length < 8
              ? 'Use at least 8 characters.'
              : null,
      _Field.confirm => value.isEmpty
          ? 'Re-enter your new password.'
          : value != _text(_Field.password)
              ? "Passwords don't match."
              : null,
    };
  }

  void _onChanged(_Field f) {
    setState(() {
      _errors[f] = null;
      _globalError = null;
      // Changing the password can fix or break the confirmation.
      if (f == _Field.password && _errors[_Field.confirm] != null) {
        _errors[_Field.confirm] = _validate(_Field.confirm);
      }
    });
    // A full code moves on, so pasting or autofilling is one step.
    if (f == _Field.code && _text(f).length == _codeLength) {
      _focusNodes[_Field.password]!.requestFocus();
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final errors = {for (final f in _Field.values) f: _validate(f)};
    final firstInvalid =
        _Field.values.where((f) => errors[f] != null).firstOrNull;
    if (firstInvalid != null) {
      setState(() => _errors.addAll(errors));
      _focusNodes[firstInvalid]!.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _globalError = null;
      _notice = null;
    });

    AuthResult result;
    try {
      result = await _authService.resetPassword(
        email: widget.email,
        code: _text(_Field.code),
        newPassword: _text(_Field.password),
      );
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;

    if (result.success) {
      // Keep the loading state so the button cannot fire again mid-transition.
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      return;
    }

    setState(() {
      _saving = false;
      final message = result.error ?? 'Something went wrong. Please try again.';
      if (message.toLowerCase().contains('code')) {
        // Wrong or expired code: clear it so the next try starts fresh.
        _errors[_Field.code] = message;
        _controllers[_Field.code]!.clear();
        _focusNodes[_Field.code]!.requestFocus();
      } else if (message.toLowerCase().contains('characters')) {
        _errors[_Field.password] = message;
        _focusNodes[_Field.password]!.requestFocus();
      } else {
        _globalError = message;
      }
    });
  }

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;
    setState(() {
      _resending = true;
      _globalError = null;
      _notice = null;
    });

    AuthResult result;
    try {
      result = await _authService.sendPasswordResetEmail(email: widget.email);
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;

    setState(() {
      _resending = false;
      if (result.success) {
        _errors[_Field.code] = null;
        _controllers[_Field.code]!.clear();
        _notice = 'A new code is on its way to ${widget.email}.';
        _startCooldown(result.resendAvailableIn ?? 60);
      } else {
        _globalError = result.error ?? _connectionError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _cooldown <= 0 && !_resending && !_saving;
    return AuthScaffold(
      title: 'Reset Password',
      subtitle: 'Enter the code we sent to ${widget.email} and choose a new '
          'password.',
      primaryAction: AuthPillButton(
        label: 'Reset password',
        loadingLabel: 'Saving…',
        loading: _saving,
        onPressed: _submit,
      ),
      footer: AuthFooterLink(
        prompt: "Didn't get it?",
        action: _resending
            ? 'Sending…'
            : _cooldown > 0
                ? 'Resend in ${_cooldown}s'
                : 'Resend code',
        onTap: canResend ? _resend : null,
      ),
      form: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              label: 'Reset code',
              placeholder: '6-digit code',
              controller: _controllers[_Field.code]!,
              errorText: _errors[_Field.code],
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_codeLength),
              ],
              autofocus: true,
              focusNode: _focusNodes[_Field.code],
              onChanged: (_) => _onChanged(_Field.code),
              onEditingComplete: () =>
                  _focusNodes[_Field.password]!.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "The code expires in 10 minutes. Can't find it? Check your spam "
              'folder.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.45,
              ),
            ),
            if (_notice != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  _notice!,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.successGreen,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AuthPasswordField(
              label: 'New password',
              placeholder: 'At least 8 characters',
              controller: _controllers[_Field.password]!,
              errorText: _errors[_Field.password],
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              showLockIcon: false,
              focusNode: _focusNodes[_Field.password],
              onChanged: (_) => _onChanged(_Field.password),
              onEditingComplete: () =>
                  _focusNodes[_Field.confirm]!.requestFocus(),
            ),
            PasswordStrengthIndicator(password: _text(_Field.password)),
            const SizedBox(height: AppSpacing.md),
            AuthPasswordField(
              label: 'Confirm new password',
              placeholder: 'Re-enter your new password',
              controller: _controllers[_Field.confirm]!,
              errorText: _errors[_Field.confirm],
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              showLockIcon: false,
              focusNode: _focusNodes[_Field.confirm],
              onChanged: (_) => _onChanged(_Field.confirm),
              onEditingComplete: _submit,
            ),
            AuthErrorSlot(message: _globalError),
          ],
        ),
      ),
    );
  }
}
