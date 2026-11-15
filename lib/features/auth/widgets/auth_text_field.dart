import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_field_shell.dart';

/// A glass text field for the auth screens: label above, an optional
/// leading icon that turns teal on focus, and any error below.
class AuthTextField extends StatefulWidget {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final String? errorText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  /// Leading glyph. Leave its colour unset: it follows the field's focus.
  final Widget? prefixIcon;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  /// Restricts what can be typed, e.g. digits only for a code.
  final List<TextInputFormatter>? inputFormatters;

  /// Multi-line input when [maxLines] is above 1 (or null to grow).
  final int? minLines;
  final int? maxLines;

  /// Caps the length; the limit is enforced without showing a counter.
  final int? maxLength;

  const AuthTextField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.controller,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
    this.autofocus = false,
    this.focusNode,
    this.onChanged,
    this.onEditingComplete,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
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
    // Autocorrect and suggestions only get in the way of email addresses.
    final isEmail = widget.keyboardType == TextInputType.emailAddress;

    return AuthFieldShell(
      label: widget.label,
      focusNode: _focus,
      errorText: widget.errorText,
      field: TextField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofocus: widget.autofocus,
        autofillHints: widget.autofillHints,
        textCapitalization: widget.textCapitalization,
        inputFormatters: [
          ...?widget.inputFormatters,
          if (widget.maxLength != null)
            LengthLimitingTextInputFormatter(widget.maxLength),
        ],
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        autocorrect: !isEmail,
        enableSuggestions: !isEmail,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
        style: AuthFieldStyle.input,
        cursorColor: const Color(0xFF1D7F8E),
        decoration: AuthFieldStyle.decoration(
          hint: widget.placeholder,
          hasError: hasError,
          prefixIcon: widget.prefixIcon,
        ),
      ),
    );
  }
}
