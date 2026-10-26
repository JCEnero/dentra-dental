import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../data/models/app_notification.dart';
import 'notification_style.dart';

/// One notification in a grouped list.
///
/// Swipe right to toggle read, swipe left to delete. Both are also
/// exposed as screen reader actions, since swiping isn't available there.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.now,
    required this.busy,
    required this.onTap,
    required this.onToggleRead,
    required this.onDelete,
  });

  final AppNotification notification;

  /// Reference time for relative timestamps, refreshed by the screen.
  final DateTime now;

  /// A request for this row is in flight; swipe actions are paused.
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.isRead;
    final category = n.category;
    final time = DentraDates.relative(n.createdAt, now: now);
    final motion = dentraMotion(context);

    final readAction = unread ? 'Mark as read' : 'Mark as unread';

    return Semantics(
      button: true,
      label: '${unread ? 'Unread. ' : ''}${category.label}. ${n.title}. '
          '${n.body}. $time',
      excludeSemantics: true,
      customSemanticsActions: busy
          ? null
          : {
              CustomSemanticsAction(label: readAction): onToggleRead,
              const CustomSemanticsAction(label: 'Delete'): onDelete,
            },
      child: Dismissible(
        key: ValueKey('notification-${n.id}'),
        direction: busy ? DismissDirection.none : DismissDirection.horizontal,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.3,
          DismissDirection.endToStart: 0.4,
        },
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Toggling read keeps the row; snap it back.
            onToggleRead();
            return false;
          }
          return true;
        },
        onDismissed: (_) => onDelete(),
        background: _SwipeAction(
          alignment: Alignment.centerLeft,
          color: AppColors.g2,
          icon: unread
              ? Icons.mark_email_read_outlined
              : Icons.mark_email_unread_outlined,
          label: unread ? 'Read' : 'Unread',
        ),
        secondaryBackground: const _SwipeAction(
          alignment: Alignment.centerRight,
          color: AppColors.danger,
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
        ),
        child: AnimatedContainer(
          duration: motion,
          curve: Curves.easeOut,
          // Unread rows carry a faint teal wash; read rows are plain glass.
          color: unread
              ? AppColors.g1.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              splashColor: AppColors.lightLavender.withValues(alpha: 0.7),
              highlightColor: AppColors.lightLavender.withValues(alpha: 0.45),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryBadge(category: category),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: motion,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight:
                                    unread ? FontWeight.w700 : FontWeight.w500,
                                color: unread
                                    ? AppColors.navy
                                    : AppColors.navy.withValues(alpha: 0.78),
                                height: 1.3,
                              ),
                              child: Text(
                                n.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${category.label} · $time',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryText
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: AnimatedScale(
                          scale: unread ? 1 : 0,
                          duration: motion,
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.g2,
                              shape: BoxShape.circle,
                            ),
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
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final NotificationCategory category;

  @override
  Widget build(BuildContext context) {
    final accent = category.accent;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Icon(category.icon, size: 18, color: accent),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final leading = alignment == Alignment.centerLeft;
    return Container(
      color: color.withValues(alpha: 0.12),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!leading) ...[
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, size: 20, color: color),
          if (leading) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
