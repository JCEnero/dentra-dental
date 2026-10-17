import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../data/models/app_notification.dart';
import 'notification_style.dart';

/// What the user chose in the detail sheet. The screen carries it out
/// after the sheet closes, so feedback appears on the page.
enum NotificationDetailAction { open, markUnread, delete }

/// Shows one notification in full, with its action, mark-as-unread and
/// delete. Resolves to null when closed without choosing.
Future<NotificationDetailAction?> showNotificationDetailSheet(
  BuildContext context,
  AppNotification notification,
) {
  return showGlassSheet<NotificationDetailAction>(
    context: context,
    title: notification.title,
    builder: (sheetContext) => _DetailBody(notification: notification),
  );
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.notification});

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
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
              decoration: BoxDecoration(
                color: category.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon, size: 15, color: category.accent),
                  const SizedBox(width: 6),
                  Text(
                    category.label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${DentraDates.medium(n.createdAt)} at '
              '${DentraDates.time(n.createdAt)}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          n.body,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: AppColors.navy,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 28),
        if (actionLabel != null) ...[
          DentraPillButton(
            label: actionLabel,
            icon: Icons.arrow_forward_rounded,
            onPressed: () => choose(NotificationDetailAction.open),
          ),
          const SizedBox(height: 12),
        ],
        DentraButtonRow(
          secondary: DentraPillButton(
            label: 'Mark as unread',
            icon: Icons.mark_email_unread_outlined,
            variant: DentraButtonVariant.outline,
            onPressed: () => choose(NotificationDetailAction.markUnread),
          ),
          primary: DentraPillButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            variant: actionLabel == null
                ? DentraButtonVariant.danger
                : DentraButtonVariant.outline,
            onPressed: () => choose(NotificationDetailAction.delete),
          ),
        ),
      ],
    );
  }
}
