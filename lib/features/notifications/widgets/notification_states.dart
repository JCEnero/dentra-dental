import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/notification_repository.dart';
import '../providers/notifications_provider.dart';

/// Placeholder rows shown while the first page loads. Pulses gently,
/// or stays still when the platform asks for reduced motion.
class NotificationSkeleton extends StatefulWidget {
  const NotificationSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  State<NotificationSkeleton> createState() => _NotificationSkeletonState();
}

class _NotificationSkeletonState extends State<NotificationSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bone = AppColors.navy.withValues(alpha: 0.07);
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: bone,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        );

    return Semantics(
      label: 'Loading notifications',
      liveRegion: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.55, end: 1).animate(_pulse),
          child: GlassCard(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                for (var i = 0; i < widget.rows; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 68,
                      color: AppGlass.divider,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: bone,
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (_, c) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bar(c.maxWidth * (i.isEven ? 0.55 : 0.7), 12),
                                const SizedBox(height: 10),
                                bar(c.maxWidth * 0.95, 10),
                                const SizedBox(height: 6),
                                bar(c.maxWidth * 0.6, 10),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered icon, title and message, for empty and error states.
class NotificationMessageState extends StatelessWidget {
  const NotificationMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent = AppColors.g2,
    this.actions = const [],
    this.mascot,
  });

  final IconData icon;

  /// Rabi in this mood, in place of [icon].
  final MascotMood? mascot;
  final String title;
  final String message;
  final Color accent;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mascot != null) ...[
                DentraMascot(mood: mascot!, size: 120),
                const SizedBox(height: 14),
              ] else ...[
                ClipOval(
                  child: GlassBlur(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: AppGlass.surface(
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Icon(icon, size: 30, color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: actions[i]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state for the current filter.
class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({super.key, required this.filter});

  final NotificationFilter filter;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (filter) {
      NotificationFilter.all => (
          "You're all caught up",
          'Screening results, account changes and security alerts will '
              'appear here.',
        ),
      NotificationFilter.unread => (
          'No unread notifications',
          "You've read everything. New updates will show up here.",
        ),
      _ => (
          'No ${filter.label.toLowerCase()} notifications',
          'Nothing in this category yet.',
        ),
    };
    return NotificationMessageState(
      icon: filter == NotificationFilter.unread
          ? Icons.done_all_rounded
          : Icons.notifications_none_rounded,
      // Only the plain "nothing here yet" page; filters keep their icon.
      mascot: filter == NotificationFilter.all ? MascotMood.cheer : null,
      title: title,
      message: message,
    );
  }
}

/// Full-page error when nothing could be loaded.
class NotificationErrorState extends StatelessWidget {
  const NotificationErrorState({
    super.key,
    required this.failure,
    required this.onRetry,
    this.onSignIn,
  });

  final NotificationFailure failure;
  final VoidCallback onRetry;

  /// Offered when the session expired.
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (failure) {
      NotificationFailure.offline => (
          Icons.cloud_off_rounded,
          "You're offline",
        ),
      NotificationFailure.unauthorized => (
          Icons.lock_outline_rounded,
          'Session expired',
        ),
      _ => (Icons.error_outline_rounded, "Couldn't load notifications"),
    };
    final expired = failure == NotificationFailure.unauthorized;

    return Semantics(
      liveRegion: true,
      child: NotificationMessageState(
        icon: icon,
        accent: AppColors.danger,
        // Offline or a server hiccup; a signed-out session keeps its lock.
        mascot: expired ? null : MascotMood.worried,
        title: title,
        message: notificationFailureMessage(failure),
        actions: [
          if (expired && onSignIn != null)
            DentraPillButton(label: 'Sign in again', onPressed: onSignIn),
          DentraPillButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            variant: expired
                ? DentraButtonVariant.outline
                : DentraButtonVariant.primary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Slim notice above the list when a refresh failed but saved
/// notifications are still shown.
class NotificationStaleBanner extends StatelessWidget {
  const NotificationStaleBanner({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  final NotificationFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = failure == NotificationFailure.offline;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.warmOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.warmOrange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off_rounded : Icons.sync_problem_rounded,
              size: 18,
              color: AppColors.navy,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                offline
                    ? "You're offline. Showing saved notifications."
                    : "Couldn't get the latest. Showing saved notifications.",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                  height: 1.35,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(44, 44),
                textStyle: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
