import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../data/models/app_notification.dart';
import '../../../core/constants/app_glass.dart';
import 'notification_style.dart';

/// What the user chose in the detail sheet. The screen carries it out
/// after the sheet closes, so feedback appears on the page.
enum NotificationDetailAction { open, markUnread, delete }

/// Shows one notification in full on a floating frosted-glass card, with
/// its action, mark-as-unread and delete. Resolves to null when closed
/// without choosing.
Future<NotificationDetailAction?> showNotificationDetailSheet(
  BuildContext context,
  AppNotification notification,
) {
  return showModalBottomSheet<NotificationDetailAction>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // Lighter than other sheets: the page behind is what the glass shows.
    barrierColor: AppColors.navy.withValues(alpha: 0.22),
    builder: (_) => _GlassNotificationCard(notification: notification),
  );
}

class _GlassNotificationCard extends StatelessWidget {
  const _GlassNotificationCard({required this.notification});

  final AppNotification notification;

  static const _radius = BorderRadius.all(Radius.circular(32));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final accent = notification.category.accent;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + media.padding.bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: media.size.height * 0.85,
          ),
          child: DecoratedBox(
            // Soft lift off the page, tinted with the category.
            decoration: BoxDecoration(
              borderRadius: _radius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.12),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: _radius,
              child: _Frost(
                child: CustomPaint(
                  foregroundPainter: const _RimPainter(radius: 32),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: _radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppGlass.floatHigh, AppGlass.floatLow],
                      ),
                    ),
                    child: DecoratedBox(
                      // A faint glow of the category colour, top left.
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.9, -1),
                          radius: 1.1,
                          colors: [
                            accent.withValues(alpha: 0.16),
                            accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                        child: _Content(notification: notification),
                      ),
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

class _Content extends StatelessWidget {
  const _Content({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final category = n.category;
    final actionLabel = n.target.actionLabel;
    void choose(NotificationDetailAction a) => Navigator.of(context).pop(a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _GlassCircle(
              size: 48,
              child: Icon(category.icon, size: 22, color: category.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: category.accent == AppColors.navy
                            ? AppColors.secondaryText
                            : category.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DentraDates.medium(n.createdAt)} · '
                      '${DentraDates.time(n.createdAt)}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _GlassCircle(
              size: 44,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Close',
                padding: EdgeInsets.zero,
                color: AppColors.navy,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            n.title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: -0.4,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          n.body,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: AppColors.navy.withValues(alpha: 0.82),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 26),
        if (actionLabel != null) ...[
          DentraPillButton(
            label: actionLabel,
            icon: Icons.arrow_forward_rounded,
            onPressed: () => choose(NotificationDetailAction.open),
          ),
          const SizedBox(height: 10),
        ],
        DentraButtonRow(
          secondary: _GlassButton(
            label: 'Mark unread',
            semanticsLabel: 'Mark as unread',
            icon: Icons.mark_email_unread_outlined,
            color: AppColors.navy,
            onPressed: () => choose(NotificationDetailAction.markUnread),
          ),
          primary: _GlassButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            color: AppColors.danger,
            onPressed: () => choose(NotificationDetailAction.delete),
          ),
        ),
      ],
    );
  }
}

// ── Glass pieces ────────────────────────────────────────────────────────────

/// Strong background blur. Skipped on web, like `GlassBlur`, where
/// backdrop filters can read stale pixels across platform views; the
/// translucent fill alone still reads as frosted there.
class _Frost extends StatelessWidget {
  const _Frost({required this.child});

  final Widget child;

  static final _blur = AppGlass.floatBlur;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return child;
    return BackdropFilter(filter: _blur, child: child);
  }
}

/// A light-catching rim: bright at the top left, fading toward the
/// bottom right, like the edge of a pane of glass.
class _RimPainter extends CustomPainter {
  const _RimPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius - 0.75)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white,
            AppColors.white.withValues(alpha: 0.35),
            AppColors.white.withValues(alpha: 0.75),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) => oldDelegate.radius != radius;
}

/// Frosted circle for the category icon and the close button.
class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.9),
            AppColors.white.withValues(alpha: 0.5),
          ],
        ),
        border: Border.all(color: AppColors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Pill button made of glass: translucent fill, bright rim, coloured
/// icon and label. Used for the quieter actions so the card stays light.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.semanticsLabel,
  });

  final String label;

  /// Fuller wording for screen readers when [label] is shortened.
  final String? semanticsLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(color: AppColors.white.withValues(alpha: 0.95)),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.white.withValues(alpha: 0.75),
              AppColors.white.withValues(alpha: 0.45),
            ],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: color.withValues(alpha: 0.10),
            highlightColor: color.withValues(alpha: 0.05),
            child: SizedBox(
              height: DentraPillButton.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 19, color: color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
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
