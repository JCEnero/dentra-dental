import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/dentra_glass_ui.dart' show dentraMotion;

/// The shared look of the auth fields: frosted white glass with a hairline
/// rim, an icon that turns teal and a soft teal glow while focused, the
/// label above and any error below.
abstract class AuthFieldStyle {
  static const BorderRadius radius = BorderRadius.all(Radius.circular(16));

  static TextStyle get input => GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.navy,
      );

  /// Glass input decoration. Icons passed in take their colour from the
  /// field's focus, so leave theirs unset.
  static InputDecoration decoration({
    required String hint,
    required bool hasError,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    final rest = hasError
        ? AppColors.coral.withValues(alpha: 0.55)
        : AppColors.g2.withValues(alpha: 0.16);
    final focus = hasError ? AppColors.coral : AppColors.g2;

    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.secondaryText.withValues(alpha: 0.6),
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: prefixIcon,
            ),
      prefixIconConstraints: prefixIcon == null
          ? null
          : const BoxConstraints(minWidth: 44, minHeight: 44),
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? AppColors.primary
            : AppColors.secondaryText.withValues(alpha: 0.8),
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints: suffixIcon == null
          ? null
          : const BoxConstraints(minWidth: 48, minHeight: 48),
      contentPadding: EdgeInsets.symmetric(
        horizontal: prefixIcon == null ? 18 : 4,
        vertical: 16,
      ),
      filled: true,
      fillColor: hasError
          ? const Color(0xFFFFF7F4).withValues(alpha: 0.92)
          : AppColors.white.withValues(alpha: 0.7),
      hoverColor: AppColors.white.withValues(alpha: 0.2),
      enabledBorder: border(rest, 1),
      focusedBorder: border(focus, 1.4),
      errorBorder: border(AppColors.coral.withValues(alpha: 0.55), 1),
      focusedErrorBorder: border(AppColors.coral, 1.4),
    );
  }
}

/// Label, field and error message for one auth input. Follows [focusNode] to
/// lift the field with a soft glow.
class AuthFieldShell extends StatefulWidget {
  const AuthFieldShell({
    super.key,
    required this.label,
    required this.focusNode,
    required this.field,
    this.errorText,
  });

  final String label;
  final FocusNode focusNode;

  /// The [TextField], using [focusNode] and [AuthFieldStyle.decoration].
  final Widget field;
  final String? errorText;

  @override
  State<AuthFieldShell> createState() => _AuthFieldShellState();
}

class _AuthFieldShellState extends State<AuthFieldShell> {
  late bool _focused = widget.focusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(AuthFieldShell old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
      _focused = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (_focused != widget.focusNode.hasFocus) {
      setState(() => _focused = widget.focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText;
    final hasError = error != null && error.isNotEmpty;
    final motion = dentraMotion(context, 200);
    final glow = hasError ? AppColors.coral : AppColors.g1;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final Widget errorLine = hasError
        ? Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: AppColors.coral,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    error,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.coral,
                    ),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox(width: double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The label keeps one colour: focus shows on the field itself. (A
        // label recoloured in place can race a font still loading.)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            widget.label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: AppColors.navy.withValues(alpha: 0.78),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: motion,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: AuthFieldStyle.radius,
            boxShadow: [
              BoxShadow(
                color: _focused
                    ? glow.withValues(alpha: 0.24)
                    : AppColors.g2.withValues(alpha: 0.05),
                blurRadius: _focused ? 18 : 10,
                spreadRadius: _focused ? -2 : -4,
                offset: Offset(0, _focused ? 6 : 3),
              ),
            ],
          ),
          child: widget.field,
        ),
        // Under reduced motion the message simply appears: AnimatedSize
        // can't run with no duration.
        if (reduced)
          errorLine
        else
          AnimatedSize(
            duration: motion,
            curve: Curves.easeOut,
            child: errorLine,
          ),
      ],
    );
  }
}
