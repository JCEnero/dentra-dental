import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../notifications/data/notification_events.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

/// Asks for the 6-digit code emailed at sign-up. Verifying signs the user
/// in. Opened from registration, and from login for an unfinished sign-up.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.resendAvailableIn = 60,
  });

  final String email;

  /// Seconds until the user may ask for another code.
  final int resendAvailableIn;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _codeLength = 6;
  static const _connectionError =
      "We couldn't reach DENTRA. Check your connection and try again.";

  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  AuthService get _authService => ref.read(authServiceProvider);

  bool _verifying = false;
  bool _resending = false;
  String? _codeError;
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
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

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

  void _onCodeChanged(String value) {
    setState(() {
      _codeError = null;
      _globalError = null;
    });
    // The last digit submits, so pasting or autofilling is one step.
    if (value.length == _codeLength) _verify();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final code = _codeCtrl.text;
    if (code.length != _codeLength) {
      setState(() => _codeError = 'Enter the 6-digit code.');
      _codeFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _globalError = null;
      _notice = null;
    });

    AuthResult result;
    try {
      result = await _authService.verifyEmail(email: widget.email, code: code);
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;

    if (result.success) {
      unawaited(ref
          .read(notificationsProvider.notifier)
          .record(NotificationEvents.welcome()));
      // Keep the loading state so the button cannot fire again mid-transition.
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      return;
    }

    setState(() {
      _verifying = false;
      final message = result.error ?? 'Something went wrong. Please try again.';
      if (message == _connectionError) {
        _globalError = message;
      } else {
        // Wrong or expired code: clear it so the next try starts fresh.
        _codeError = message;
        _codeCtrl.clear();
        _codeFocus.requestFocus();
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
      result = await _authService.resendVerificationCode(email: widget.email);
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;

    setState(() {
      _resending = false;
      if (result.success) {
        _codeError = null;
        _codeCtrl.clear();
        _notice = 'A new code is on its way to ${widget.email}.';
        _startCooldown(result.resendAvailableIn ?? 60);
      } else {
        _globalError = result.error ?? _connectionError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _cooldown <= 0 && !_resending && !_verifying;
    return AuthScaffold(
      title: 'Check Your Email',
      subtitle: 'We sent a 6-digit code to ${widget.email}.',
      primaryAction: AuthPillButton(
        label: 'Verify',
        semanticLabel: 'Verify email',
        loadingLabel: 'Verifying…',
        loading: _verifying,
        onPressed: _verify,
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
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: 'Verification code',
            placeholder: '6-digit code',
            controller: _codeCtrl,
            errorText: _codeError,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_codeLength),
            ],
            autofocus: true,
            focusNode: _codeFocus,
            onChanged: _onCodeChanged,
            onEditingComplete: _verify,
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
          AuthErrorSlot(message: _globalError),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _verifying ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: AppColors.primary,
                shape: const StadiumBorder(),
              ),
              child: Text(
                'Use a different email',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
