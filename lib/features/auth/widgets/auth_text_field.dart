import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';

/// A styled text field that matches the DENTRA design system.
///
/// Displays a label above the input and an optional leading icon.
/// Error messages appear below the field with a smooth fade-in.
class AuthTextField extends StatelessWidget {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final String? errorText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? prefixIcon;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

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
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    // Autocorrect and suggestions only get in the way of email addresses.
    final isEmail = keyboardType == TextInputType.emailAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
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
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofocus: autofocus,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          autocorrect: !isEmail,
          enableSuggestions: !isEmail,
          onChanged: onChanged,
          onEditingComplete: onEditingComplete,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.navy,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaryText.withValues(alpha: 0.6),
            ),
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: prefixIcon,
                  )
                : null,
            prefixIconConstraints: prefixIcon != null
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : null,
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
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(
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
                          errorText!,
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
