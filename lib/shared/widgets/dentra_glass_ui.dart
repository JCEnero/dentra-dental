import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_glass.dart';
import '../../core/constants/app_radius.dart';
import 'glass_card.dart';

// Shared glass building blocks: glass sheets and dialogs,
// pill buttons with loading/disabled states, and snackbar feedback.

/// Respects the platform "reduce motion" setting.
Duration dentraMotion(BuildContext context, [int ms = 220]) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: ms);

/// Dims the page behind sheets and dialogs. Navy, not black, so the
/// backdrop keeps its teal cast; light, so the glass shows through.
final Color _barrier = AppGlass.barrier;

/// Frosted glass for anything that appears over the page (dialogs,
/// sheets, snackbars): blur, a translucent fill like Home's cards and a
/// bright rim. No drop shadow, like Home: under see-through glass it would
/// show through as a grey band.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.border,
    this.tint,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Border? border;

  /// A faint wash of colour over the glass, e.g. for an error.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: GlassBlur(
        strong: true,
        child: DecoratedBox(
          decoration:
              AppGlass.floating(borderRadius: borderRadius, border: border),
          child: tint == null
              ? child
              : DecoratedBox(
                  decoration:
                      BoxDecoration(color: tint, borderRadius: borderRadius),
                  child: child,
                ),
        ),
      ),
    );
  }
}

// ── Bottom sheets ─────────────────────────────────────────────────────────────

/// Opens a frosted-glass bottom sheet with a title, close button and
/// scrollable body. The body moves up with the keyboard.
///
/// Opens on the root navigator so it covers the bottom nav bar.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: _barrier,
    elevation: 0,
    builder: (sheetContext) => _GlassSheet(
      title: title,
      subtitle: subtitle,
      child: Builder(builder: builder),
    ),
  );
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  static const _radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: media.size.height * 0.9,
          ),
          child: GlassSurface(
            borderRadius: _radius,
            border: const Border(
              top: BorderSide(color: AppGlass.border, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: AppColors.secondaryText,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Close',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppColors.white.withValues(alpha: 0.7),
                          foregroundColor: AppColors.navy,
                          fixedSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      20,
                      24,
                      24 + media.padding.bottom,
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────────

/// Opens [builder] as a centered glass dialog that scales and fades in.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: _barrier,
    transitionDuration: dentraMotion(context, 200),
    pageBuilder: (dialogContext, _, __) => builder(dialogContext),
    transitionBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Glass panel for dialog content: icon badge, title, message, then
/// [children] (usually the actions).
class GlassDialogFrame extends StatelessWidget {
  const GlassDialogFrame({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.children,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> children;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.dangerInk : AppColors.primary;
    final media = MediaQuery.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            type: MaterialType.transparency,
            child: GlassSurface(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: AppRadius.lgAll,
                        ),
                        child: Icon(icon, color: accent, size: 24),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks the user to confirm an action. Resolves to true only on confirm.
Future<bool> showGlassConfirmDialog({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showGlassDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassDialogFrame(
      icon: icon,
      title: title,
      message: message,
      destructive: destructive,
      children: [
        DentraButtonRow(
          secondary: DentraPillButton(
            label: cancelLabel,
            variant: DentraButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          primary: DentraPillButton(
            label: confirmLabel,
            variant: destructive
                ? DentraButtonVariant.danger
                : DentraButtonVariant.primary,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

// ── Buttons ───────────────────────────────────────────────────────────────────

enum DentraButtonVariant { primary, outline, danger }

/// Pill button with loading and disabled states.
///
/// Pass `onPressed: null` to disable it; it fades to show it cannot be
/// used. While [loading] it shows a spinner and ignores taps.
class DentraPillButton extends StatelessWidget {
  const DentraPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DentraButtonVariant.primary,
    this.loading = false,
    this.loadingLabel,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final DentraButtonVariant variant;
  final bool loading;
  final String? loadingLabel;
  final IconData? icon;

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final filled = variant != DentraButtonVariant.outline;
    final foreground = switch (variant) {
      DentraButtonVariant.outline => AppColors.navy,
      DentraButtonVariant.danger => AppColors.dangerInk,
      _ => AppColors.white,
    };
    final textStyle = GoogleFonts.outfit(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
      color: foreground,
    );
    final busyLabel = loadingLabel ?? label;

    final Widget content = loading
        ? Row(
            key: const ValueKey('loading'),
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foreground),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  busyLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          )
        : Row(
            key: const ValueKey('label'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          );

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(height / 2),
      gradient: switch (variant) {
        DentraButtonVariant.primary => const LinearGradient(
            colors: [AppColors.cardSolid, AppColors.g2],
          ),
        _ => null,
      },
      color: switch (variant) {
        // Pale red, never solid.
        DentraButtonVariant.danger => AppColors.dangerTint,
        DentraButtonVariant.outline => AppColors.white.withValues(alpha: 0.6),
        _ => null,
      },
      border: switch (variant) {
        DentraButtonVariant.outline =>
          Border.all(color: AppColors.g2.withValues(alpha: 0.28)),
        DentraButtonVariant.danger => Border.all(color: AppColors.dangerBorder),
        _ => null,
      },
      boxShadow: filled && enabled && variant != DentraButtonVariant.danger
          ? [
              BoxShadow(
                color: AppColors.g2.withValues(alpha: 0.24),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ]
          : null,
    );

    return Semantics(
      button: true,
      enabled: enabled && !loading,
      label: loading ? busyLabel : label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: dentraMotion(context, 180),
        // Disabled buttons stay readable but clearly inactive. Loading
        // buttons keep full strength: they are working, not unavailable.
        opacity: enabled || loading ? 1 : 0.45,
        child: DecoratedBox(
          decoration: decoration,
          child: Material(
            type: MaterialType.transparency,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: loading ? null : onPressed,
              child: SizedBox(
                height: height,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: AnimatedSwitcher(
                      duration: dentraMotion(context, 180),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays out a secondary and primary action side by side, or stacked
/// (primary first) when the screen is too narrow or text is very large.
class DentraButtonRow extends StatelessWidget {
  const DentraButtonRow({
    super.key,
    required this.secondary,
    required this.primary,
  });

  final Widget secondary;
  final Widget primary;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280 || textScale > 1.4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: 10), secondary],
          );
        }
        return Row(
          children: [
            Expanded(child: secondary),
            const SizedBox(width: 12),
            Expanded(child: primary),
          ],
        );
      },
    );
  }
}

// ── Feedback ──────────────────────────────────────────────────────────────────

enum DentraFeedbackTone { success, error, info }

/// Shows a floating snackbar in the brand style. Pass [onRetry] to offer
/// a retry action on errors.
void showDentraSnack(
  BuildContext context,
  String message, {
  DentraFeedbackTone tone = DentraFeedbackTone.success,
  VoidCallback? onRetry,
  String retryLabel = 'Retry',
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(dentraSnackBar(
      message,
      tone: tone,
      onRetry: onRetry,
      retryLabel: retryLabel,
    ));
}

/// The snackbar used by [showDentraSnack], for callers that hold a
/// [ScaffoldMessengerState] after their own context is gone.
SnackBar dentraSnackBar(
  String message, {
  DentraFeedbackTone tone = DentraFeedbackTone.success,
  VoidCallback? onRetry,
  String retryLabel = 'Retry',
}) {
  final (color, icon) = switch (tone) {
    DentraFeedbackTone.success => (
        AppColors.successGreen,
        Icons.check_circle_rounded
      ),
    DentraFeedbackTone.error => (AppColors.dangerInk, Icons.error_rounded),
    DentraFeedbackTone.info => (AppColors.g2, Icons.info_rounded),
  };
  const radius = AppRadius.lgAll;

  // Glass like the rest of the app: navy text, the tone only in the icon,
  // a faint wash and the rim. Red is pale, never a solid bar.
  return SnackBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    shape: const RoundedRectangleBorder(borderRadius: radius),
    duration: Duration(seconds: onRetry != null ? 5 : 3),
    content: GlassSurface(
      borderRadius: radius,
      tint: (tone == DentraFeedbackTone.error ? AppColors.danger : color)
          .withValues(alpha: 0.08),
      border: Border.all(
        color: tone == DentraFeedbackTone.error
            ? AppColors.dangerBorder
            : color.withValues(alpha: 0.28),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, onRetry == null ? 16 : 4, 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                ),
              ),
            ),
            if (onRetry != null)
              Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onRetry();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.g2,
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    retryLabel,
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Inline status line for sheets, e.g. after a switch fails to save.
/// Animates in and out; renders nothing when [message] is null.
class DentraInlineNotice extends StatelessWidget {
  const DentraInlineNotice({
    super.key,
    required this.message,
    this.tone = DentraFeedbackTone.error,
  });

  final String? message;
  final DentraFeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      DentraFeedbackTone.success => AppColors.successGreen,
      DentraFeedbackTone.error => AppColors.dangerInk,
      DentraFeedbackTone.info => AppColors.g2,
    };
    final icon = switch (tone) {
      DentraFeedbackTone.success => Icons.check_circle_outline_rounded,
      DentraFeedbackTone.error => Icons.error_outline_rounded,
      DentraFeedbackTone.info => Icons.info_outline_rounded,
    };

    return AnimatedSize(
      duration: dentraMotion(context),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message!,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navy,
                          height: 1.45,
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

/// Selectable pill used for categories and other single-choice options.
class DentraChoiceChip extends StatelessWidget {
  const DentraChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: dentraMotion(context, 180),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.g2
                  : AppColors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? AppColors.g2
                    : AppColors.g2.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.white),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.white : AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
