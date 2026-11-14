import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart' show dentraMotion;
import 'auth_field_shell.dart';

/// A glass password field with a lock icon and a show / hide toggle.
class AuthPasswordField extends StatefulWidget {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final String? errorText;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final Iterable<String>? autofillHints;

  /// Shows the leading lock icon. Minimal layouts can turn it off.
  final bool showLockIcon;

  const AuthPasswordField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.controller,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.onChanged,
    this.onEditingComplete,
    this.autofillHints,
    this.showLockIcon = true,
  });

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  /// Used when the caller doesn't pass a focus node of its own.
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return AuthFieldShell(
      label: widget.label,
      focusNode: _focus,
      errorText: widget.errorText,
      field: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: _obscure,
        obscuringCharacter: '•',
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
        style: AuthFieldStyle.input,
        cursorColor: const Color(0xFF1D7F8E),
        decoration: AuthFieldStyle.decoration(
          hint: widget.placeholder,
          hasError: hasError,
          prefixIcon: widget.showLockIcon
              ? const Icon(Icons.lock_outline_rounded, size: 20)
              : null,
          // A real tap target with a screen-reader label. The eye turns
          // teal while the password shows, so its state reads at a glance.
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              tooltip: _obscure ? 'Show password' : 'Hide password',
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                highlightColor: AppColors.g1.withValues(alpha: 0.12),
              ),
              icon: AnimatedSwitcher(
                duration: dentraMotion(context, 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  key: ValueKey(_obscure),
                  size: 20,
                  color: _obscure
                      ? AppColors.secondaryText.withValues(alpha: 0.8)
                      : AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
