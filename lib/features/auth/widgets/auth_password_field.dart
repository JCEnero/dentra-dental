import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';

/// A styled password field with visibility toggle.
/// Matches the DENTRA design system.
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

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 7),
        // Input
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.navy,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaryText.withValues(alpha: 0.6),
            ),
            prefixIcon: widget.showLockIcon
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AppColors.secondaryText,
                    ),
                  )
                : null,
            prefixIconConstraints: widget.showLockIcon
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : null,
            // IconButton gives the toggle a real tap target and a
            // screen-reader label.
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              tooltip: _obscure ? 'Show password' : 'Hide password',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  key: ValueKey(_obscure),
                  size: 18,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor:
                hasError ? const Color(0xFFFFF5F3) : AppColors.lightLavender,
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(
                color: hasError
                    ? AppColors.coral.withValues(alpha: 0.6)
                    : AppColors.border,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(
                color: hasError ? AppColors.coral : AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(
                color: AppColors.coral.withValues(alpha: 0.6),
                width: 1.0,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: const BorderSide(
                color: AppColors.coral,
                width: 1.5,
              ),
            ),
          ),
        ),
        // Error message
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 5, left: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 13,
                        color: AppColors.coral,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.errorText!,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.coral,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
