import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../notifications/data/notification_events.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

enum _Field { name, email, password, confirm }

/// Sign-up screen, built on the shared [AuthScaffold] so it matches login.
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  static const _genericError = 'Something went wrong. Please try again.';
  static const _connectionError =
      "We couldn't reach DENTRA. Check your connection and try again.";

  // ── Controllers & focus nodes ────────────────────────────────
  final _controllers = {
    for (final f in _Field.values) f: TextEditingController(),
  };
  final _focusNodes = {for (final f in _Field.values) f: FocusNode()};
  // App-wide session, so the signed-in user is visible after navigation.
  AuthService get _authService => ref.read(authServiceProvider);

  // ── State ────────────────────────────────────────────────────
  bool _isRegistering = false;
  bool _submitted = false; // true once the first submit attempt is made

  final Map<_Field, String?> _errors = {};
  String? _globalError;

  @override
  void initState() {
    super.initState();
    for (final f in _Field.values) {
      _focusNodes[f]!.addListener(() => _onFocusChanged(f));
    }
  }

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

  // ── Validation ───────────────────────────────────────────────

  String _text(_Field f) => switch (f) {
        // Passwords are taken as typed; spaces may be intentional.
        _Field.password || _Field.confirm => _controllers[f]!.text,
        _ => _controllers[f]!.text.trim(),
      };

  String? _check(_Field f) {
    final value = _text(f);
    return switch (f) {
      _Field.name => value.isEmpty
          ? 'Enter your full name.'
          : value.length < 2
              ? 'Name must be at least 2 characters.'
              : null,
      _Field.email => AuthValidators.email(value),
      _Field.password => value.isEmpty
          ? 'Create a password.'
          : value.length < 8
              ? 'Use at least 8 characters.'
              : null,
      _Field.confirm => value.isEmpty
          ? 'Re-enter your password.'
          : value != _text(_Field.password)
              ? "Passwords don't match."
              : null,
    };
  }

  /// Validates a field once the user leaves it, but never nags about an
  /// empty field they have not typed in yet.
  void _onFocusChanged(_Field f) {
    if (_focusNodes[f]!.hasFocus) return;
    if (_text(f).isEmpty && !_submitted) return;
    setState(() => _errors[f] = _check(f));
  }

  /// While an error is showing, re-check live so it clears as soon as the
  /// input is fixed. Always rebuilds (the strength meter tracks the
  /// password).
  void _onChanged(_Field f) {
    setState(() {
      _globalError = null;
      if (_submitted || _errors[f] != null) _errors[f] = _check(f);
      // Changing the password can fix or break the confirmation.
      if (f == _Field.password &&
          _text(_Field.confirm).isNotEmpty &&
          (_submitted || _errors[_Field.confirm] != null)) {
        _errors[_Field.confirm] = _check(_Field.confirm);
      }
    });
  }

  void _focusNext(_Field f) =>
      _focusNodes[_Field.values[f.index + 1]]!.requestFocus();

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _register() async {
    if (_isRegistering) return;

    setState(() {
      _submitted = true;
      _globalError = null;
      for (final f in _Field.values) {
        _errors[f] = _check(f);
      }
    });

    // Send focus to the first field that needs attention.
    for (final f in _Field.values) {
      if (_errors[f] != null) {
        _focusNodes[f]!.requestFocus();
        return;
      }
    }

    FocusScope.of(context).unfocus();
    setState(() => _isRegistering = true);

    AuthResult result;
    try {
      result = await _authService.registerWithEmail(
        fullName: _text(_Field.name),
        email: _text(_Field.email),
        password: _text(_Field.password),
      );
    } catch (_) {
      // Never surface raw exception text: it can leak implementation details.
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
      _isRegistering = false;
      _globalError = result.error ?? _genericError;
    });
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
      ),
    );
  }

  void _openTerms() => _showInfoSheet(
        title: 'Terms of Service',
        body:
            'By using DENTRA, you agree to use the application responsibly and '
            'in accordance with all applicable laws. DENTRA is intended for '
            'informational purposes and does not constitute medical advice. '
            'Always consult a qualified dental professional for clinical '
            'decisions.',
      );

  void _openPrivacy() => _showInfoSheet(
        title: 'Privacy Policy',
        body: 'DENTRA collects only the information necessary to provide its '
            'services. Your dental imaging data is stored securely and is never '
            'shared with third parties without your explicit consent. You may '
            'request deletion of your data at any time from your profile '
            'settings.',
      );

  void _showInfoSheet({required String title, required String body}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Text(
                body,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthPillButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create Account',
      subtitle: 'Your smile journey starts here.',
      // Four fields: give them the room instead of a taller hero.
      expandHero: false,
      notice: _TermsText(onTermsTap: _openTerms, onPrivacyTap: _openPrivacy),
      primaryAction: AuthPillButton(
        label: 'Create Account',
        semanticLabel: 'Create account',
        loadingLabel: 'Creating account…',
        loading: _isRegistering,
        onPressed: _register,
      ),
      footer: AuthFooterLink(
        prompt: 'Already have an account?',
        action: 'Log in',
        onTap: _isRegistering ? null : _goToLogin,
      ),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: 'Full name',
            placeholder: 'Your name',
            controller: _controllers[_Field.name]!,
            errorText: _errors[_Field.name],
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            focusNode: _focusNodes[_Field.name],
            onChanged: (_) => _onChanged(_Field.name),
            onEditingComplete: () => _focusNext(_Field.name),
          ),
          const SizedBox(height: AppSpacing.md),
          AuthTextField(
            label: 'Email',
            placeholder: 'name@example.com',
            controller: _controllers[_Field.email]!,
            errorText: _errors[_Field.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            focusNode: _focusNodes[_Field.email],
            onChanged: (_) => _onChanged(_Field.email),
            onEditingComplete: () => _focusNext(_Field.email),
          ),
          const SizedBox(height: AppSpacing.md),
          AuthPasswordField(
            label: 'Password',
            placeholder: 'At least 8 characters',
            controller: _controllers[_Field.password]!,
            errorText: _errors[_Field.password],
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            showLockIcon: false,
            focusNode: _focusNodes[_Field.password],
            onChanged: (_) => _onChanged(_Field.password),
            onEditingComplete: () => _focusNext(_Field.password),
          ),
          PasswordStrengthIndicator(password: _text(_Field.password)),
          const SizedBox(height: AppSpacing.md),
          AuthPasswordField(
            label: 'Confirm password',
            placeholder: 'Re-enter your password',
            controller: _controllers[_Field.confirm]!,
            errorText: _errors[_Field.confirm],
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            showLockIcon: false,
            focusNode: _focusNodes[_Field.confirm],
            onChanged: (_) => _onChanged(_Field.confirm),
            onEditingComplete: _register,
          ),
          AuthErrorSlot(message: _globalError),
        ],
      ),
    );
  }
}

/// Terms & Privacy consent line with tappable links. Stateful so the tap
/// recognizers are created once and disposed.
class _TermsText extends StatefulWidget {
  const _TermsText({required this.onTermsTap, required this.onPrivacyTap});

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  State<_TermsText> createState() => _TermsTextState();
}

class _TermsTextState extends State<_TermsText> {
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => widget.onTermsTap();
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => widget.onPrivacyTap();

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.outfit(
      fontSize: 13,
      color: AppColors.secondaryText,
      height: 1.55,
    );
    final linkStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'By creating an account, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: _termsTap,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: _privacyTap,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
