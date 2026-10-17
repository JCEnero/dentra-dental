import 'dart:async';

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
import 'registration_screen.dart';
import 'verify_email_screen.dart';

/// Sign-in screen, built on the shared [AuthScaffold].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _genericError = 'Something went wrong. Please try again.';
  static const _connectionError =
      "We couldn't reach DENTRA. Check your connection and try again.";

  // ── Controllers & focus nodes ────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  // App-wide session, so the signed-in user is visible after navigation.
  AuthService get _authService => ref.read(authServiceProvider);

  // ── State ────────────────────────────────────────────────────
  bool _isSigningIn = false;
  bool _isGoogleSigningIn = false;
  bool _submitted = false; // true once the first submit attempt is made

  String? _emailError;
  String? _passwordError;
  String? _globalError;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_onEmailFocusChanged);
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_onEmailFocusChanged);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Validation ───────────────────────────────────────────────

  String? _passwordErrorFor(String password) =>
      password.isEmpty ? 'Enter your password.' : null;

  /// Validates the email once the user leaves the field, but never nags
  /// about an empty field they have not typed in yet.
  void _onEmailFocusChanged() {
    if (_emailFocus.hasFocus) return;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty && !_submitted) return;
    setState(() => _emailError = AuthValidators.email(email));
  }

  /// While an error is showing, re-check live so it clears as soon as the
  /// input is fixed.
  void _onEmailChanged(String _) {
    setState(() {
      _globalError = null;
      if (_submitted || _emailError != null) {
        _emailError = AuthValidators.email(_emailCtrl.text.trim());
      }
    });
  }

  void _onPasswordChanged(String _) {
    setState(() {
      _globalError = null;
      if (_submitted || _passwordError != null) {
        _passwordError = _passwordErrorFor(_passwordCtrl.text);
      }
    });
  }

  // ── Actions ──────────────────────────────────────────────────

  /// Either sign-in path is running; the other stays locked meanwhile.
  bool get _busy => _isSigningIn || _isGoogleSigningIn;

  Future<void> _signIn() async {
    if (_busy) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() {
      _submitted = true;
      _globalError = null;
      _emailError = AuthValidators.email(email);
      _passwordError = _passwordErrorFor(password);
    });

    // Send focus to the first field that needs attention.
    if (_emailError != null) {
      _emailFocus.requestFocus();
      return;
    }
    if (_passwordError != null) {
      _passwordFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSigningIn = true);

    AuthResult result;
    try {
      result = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
    } catch (_) {
      // Never surface raw exception text: it can leak implementation details.
      result = const AuthResult(success: false, error: _connectionError);
    }

    if (!mounted) return;

    if (result.success) {
      unawaited(ref
          .read(notificationsProvider.notifier)
          .record(NotificationEvents.signedIn()));
      // Keep the loading state so the button cannot fire again mid-transition.
      _navigateToApp();
      return;
    }

    // Right password, unfinished sign-up: a code was just emailed.
    if (result.needsVerification) {
      setState(() => _isSigningIn = false);
      _openVerification(email);
      return;
    }

    setState(() {
      _isSigningIn = false;
      _globalError = result.error ?? _genericError;
    });
  }

  void _openVerification(String email) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VerifyEmailScreen(email: email),
    ));
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isGoogleSigningIn = true;
      _globalError = null;
    });

    AuthResult result;
    try {
      result = await _authService.signInWithGoogle();
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }

    if (!mounted) return;

    if (result.success) {
      unawaited(ref
          .read(notificationsProvider.notifier)
          .record(NotificationEvents.signedIn()));
      _navigateToApp();
      return;
    }

    // No error means the user closed the Google sheet: nothing to report.
    setState(() {
      _isGoogleSigningIn = false;
      _globalError = result.error;
    });
  }

  Future<void> _forgotPassword() async {
    final resetEmail = await showDialog<String>(
      context: context,
      barrierColor: AppColors.navy.withValues(alpha: 0.35),
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: _emailCtrl.text.trim(),
      ),
    );

    if (resetEmail == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      _snackBar('Sending reset link to $resetEmail…', AppColors.primary),
    );

    AuthResult result;
    try {
      result = await _authService.sendPasswordResetEmail(email: resetEmail);
    } catch (_) {
      result = const AuthResult(success: false, error: _connectionError);
    }
    if (!mounted) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        result.success
            ? _snackBar(
                'Password reset link sent. Check your inbox.',
                AppColors.successGreen,
              )
            : _snackBar(result.error ?? _genericError, AppColors.coral),
      );
  }

  SnackBar _snackBar(String message, Color color) => SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        duration: const Duration(seconds: 3),
      );

  void _navigateToApp() {
    // Replace the entire navigation stack with the main app shell.
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  void _goToRegister() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const RegistrationScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Your smile journey continues.',
      primaryAction: AuthPillButton(
        label: 'Log In',
        semanticLabel: 'Log in',
        loadingLabel: 'Logging in…',
        loading: _isSigningIn,
        onPressed: _isGoogleSigningIn ? null : _signIn,
      ),
      footer: AuthFooterLink(
        prompt: "Don't have an account?",
        action: 'Sign up',
        onTap: _busy ? null : _goToRegister,
      ),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Offered only once Google sign-in is configured.
          if (_authService.googleSignInAvailable) ...[
            GoogleAuthButton(
              label: 'Continue with Google',
              isLoading: _isGoogleSigningIn,
              onTap: _isSigningIn ? null : _signInWithGoogle,
            ),
            const SizedBox(height: AppSpacing.md),
            const AuthDivider(),
            const SizedBox(height: AppSpacing.md),
          ],
          AuthTextField(
            label: 'Email',
            placeholder: 'name@example.com',
            controller: _emailCtrl,
            errorText: _emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            focusNode: _emailFocus,
            onChanged: _onEmailChanged,
            onEditingComplete: _passwordFocus.requestFocus,
          ),
          const SizedBox(height: AppSpacing.md),
          AuthPasswordField(
            label: 'Password',
            placeholder: 'Enter your password',
            controller: _passwordCtrl,
            errorText: _passwordError,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            showLockIcon: false,
            focusNode: _passwordFocus,
            onChanged: _onPasswordChanged,
            onEditingComplete: _signIn,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _forgotPassword,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: AppColors.primary,
                shape: const StadiumBorder(),
              ),
              child: Text(
                'Forgot password?',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          AuthErrorSlot(message: _globalError),
        ],
      ),
    );
  }
}

// ── Forgot password dialog ────────────────────────────────────────────────────

/// Collects the reset email and validates it in place. Pops with the
/// email to send to, or null when cancelled.
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final _controller = TextEditingController(text: widget.initialEmail);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _controller.text.trim();
    final error = AuthValidators.email(email);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xxlAll),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Reset password',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                "Enter your email and we'll send you a reset link.",
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md + 4),
              AuthTextField(
                label: 'Email',
                placeholder: 'name@example.com',
                controller: _controller,
                errorText: _error,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.send,
                autofillHints: const [AutofillHints.email],
                autofocus: true,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onEditingComplete: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthPillButton(label: 'Send link', onPressed: _submit),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  foregroundColor: AppColors.secondaryText,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
