import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/reset_password_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/widgets/auth_password_field.dart';
import '../../auth/widgets/password_strength_indicator.dart';
import '../utils/profile_validators.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';

/// Opens the change-password sheet. Resolves to true once the password
/// has been changed.
Future<bool> showChangePasswordSheet(
  BuildContext context, {
  required String email,
}) async {
  final changed = await showGlassSheet<bool>(
    context: context,
    title: 'Change password',
    subtitle: 'Enter your current password, then choose a new one.',
    builder: (_) => _ChangePasswordForm(email: email),
  );
  return changed ?? false;
}

enum _Field { current, next, confirm }

class _ChangePasswordForm extends ConsumerStatefulWidget {
  const _ChangePasswordForm({required this.email});

  final String email;

  @override
  ConsumerState<_ChangePasswordForm> createState() =>
      _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<_ChangePasswordForm> {
  static const _connectionError =
      "We couldn't reach DENTRA. Check your connection and try again.";

  final _controllers = {
    for (final f in _Field.values) f: TextEditingController()
  };
  final _focusNodes = {for (final f in _Field.values) f: FocusNode()};
  final _errors = <_Field, String?>{};

  bool _submitted = false;
  bool _saving = false;
  bool _sendingReset = false;
  String? _formError;
  String? _resetNotice;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  String _text(_Field f) => _controllers[f]!.text;

  String? _validate(_Field f) => switch (f) {
        _Field.current => ProfileValidators.currentPassword(_text(f)),
        _Field.next => ProfileValidators.newPassword(_text(f),
            current: _text(_Field.current)),
        _Field.confirm => ProfileValidators.confirmPassword(
            _text(f),
            newPassword: _text(_Field.next),
          ),
      };

  /// Re-checks live once the user has tried to submit or an error is
  /// showing, so messages clear as soon as the input is fixed.
  void _onChanged(_Field f) {
    setState(() {
      _formError = null;
      if (_submitted || _errors[f] != null) _errors[f] = _validate(f);
      // The new password affects the confirmation, and vice versa.
      if (f == _Field.next &&
          (_submitted || _errors[_Field.confirm] != null) &&
          _text(_Field.confirm).isNotEmpty) {
        _errors[_Field.confirm] = _validate(_Field.confirm);
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _submitted = true;
      _formError = null;
      for (final f in _Field.values) {
        _errors[f] = _validate(f);
      }
    });

    final firstInvalid =
        _Field.values.where((f) => _errors[f] != null).firstOrNull;
    if (firstInvalid != null) {
      _focusNodes[firstInvalid]!.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    AuthResult result;
    try {
      result = await ref.read(authServiceProvider).changePassword(
            currentPassword: _text(_Field.current),
            newPassword: _text(_Field.next),
          );
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }

    // Inputs are kept so the user can correct and retry.
    setState(() {
      _saving = false;
      final message = result.error ?? 'Something went wrong. Please try again.';
      if (message.toLowerCase().contains('current password')) {
        _errors[_Field.current] = message;
        _focusNodes[_Field.current]!.requestFocus();
      } else {
        _formError = message;
      }
    });
  }

  Future<void> _sendResetLink() async {
    if (_sendingReset) return;
    setState(() {
      _sendingReset = true;
      _resetNotice = null;
    });
    AuthResult result;
    try {
      result = await ref
          .read(authServiceProvider)
          .sendPasswordResetEmail(email: widget.email);
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;
    setState(() {
      _sendingReset = false;
      _resetNotice = result.success ? null : (result.error ?? _connectionError);
    });
    if (!result.success) return;
    // The reset screen signs in afresh and returns to home on success.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResetPasswordScreen(
        email: widget.email,
        resendAvailableIn: result.resendAvailableIn ?? 60,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPasswordField(
            label: 'Current password',
            placeholder: 'Enter your current password',
            controller: _controllers[_Field.current]!,
            focusNode: _focusNodes[_Field.current],
            errorText: _errors[_Field.current],
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => _onChanged(_Field.current),
            onEditingComplete: () => _focusNodes[_Field.next]!.requestFocus(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  widget.email.isEmpty || _sendingReset ? null : _sendResetLink,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.g2,
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                _sendingReset ? 'Sending code…' : 'Forgot password?',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          DentraInlineNotice(
            message: _resetNotice,
            tone: DentraFeedbackTone.error,
          ),
          const SizedBox(height: 8),
          AuthPasswordField(
            label: 'New password',
            placeholder: 'At least 8 characters',
            controller: _controllers[_Field.next]!,
            focusNode: _focusNodes[_Field.next],
            errorText: _errors[_Field.next],
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => _onChanged(_Field.next),
            onEditingComplete: () =>
                _focusNodes[_Field.confirm]!.requestFocus(),
          ),
          PasswordStrengthIndicator(password: _text(_Field.next)),
          const SizedBox(height: 10),
          _Requirements(password: _text(_Field.next)),
          const SizedBox(height: 18),
          AuthPasswordField(
            label: 'Confirm new password',
            placeholder: 'Re-enter your new password',
            controller: _controllers[_Field.confirm]!,
            focusNode: _focusNodes[_Field.confirm],
            errorText: _errors[_Field.confirm],
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onChanged: (_) => _onChanged(_Field.confirm),
            onEditingComplete: _submit,
          ),
          DentraInlineNotice(message: _formError),
          const SizedBox(height: 24),
          DentraPillButton(
            label: 'Update password',
            loadingLabel: 'Updating…',
            loading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Live checklist of the new-password rules.
class _Requirements extends StatelessWidget {
  const _Requirements({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = [
      ('At least 8 characters', password.length >= 8),
      ('Contains a number', RegExp(r'\d').hasMatch(password)),
      (
        'Uppercase and lowercase letters',
        RegExp(r'[A-Z]').hasMatch(password) &&
            RegExp(r'[a-z]').hasMatch(password),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, met) in rules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Semantics(
              label: '$label, ${met ? 'met' : 'not met'}',
              excludeSemantics: true,
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: dentraMotion(context, 180),
                    child: Icon(
                      met
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(met),
                      size: 16,
                      color: met
                          ? AppColors.successGreen
                          : AppColors.secondaryText.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: met ? AppColors.navy : AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
