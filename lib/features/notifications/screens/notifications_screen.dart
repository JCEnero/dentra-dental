import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../history/screens/screening_detail_screen.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../data/models/app_notification.dart';
import '../data/notification_repository.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_detail_sheet.dart';
import '../widgets/notification_row.dart';
import '../widgets/notification_states.dart';

/// The notification center.
///
/// Pops with [NotificationTarget.profile] when a notification asks to open
/// account settings, so the caller can switch to the Profile tab.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  /// Fades and lifts in; instant when the platform asks for reduced motion.
  static Route<NotificationTarget?> route() {
    return PageRouteBuilder<NotificationTarget?>(
      pageBuilder: (_, __, ___) => const NotificationsScreen(),
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Keeps relative timestamps ("5 minutes ago") current while open.
  late final Timer _clock;
  DateTime _now = DateTime.now();

  // Prevents opening two sheets or screens from a fast double tap.
  bool _navigating = false;

  NotificationsNotifier get _notifier =>
      ref.read(notificationsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Always show the latest when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(notificationsProvider).hasValue) _notifier.refresh();
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _showError(Object error, {VoidCallback? onRetry}) {
    if (!mounted) return;
    final failure = error is NotificationException
        ? error.failure
        : NotificationFailure.server;
    showDentraSnack(
      context,
      switch (failure) {
        NotificationFailure.offline =>
          "You're offline. Your change wasn't saved.",
        NotificationFailure.unauthorized =>
          'Your session has expired. Sign in again.',
        _ => "That didn't work. Please try again.",
      },
      tone: DentraFeedbackTone.error,
      onRetry: onRetry,
    );
  }

  Future<void> _toggleRead(AppNotification n) async {
    try {
      await _notifier.setRead(n.id, read: !n.isRead);
    } catch (e) {
      _showError(e, onRetry: () => _toggleRead(n));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _notifier.markAllRead();
      if (!mounted) return;
      showDentraSnack(context, 'All notifications marked as read.');
    } catch (e) {
      _showError(e, onRetry: _markAllRead);
    }
  }

  Future<void> _delete(AppNotification n) async {
    final AppNotification? removed;
    try {
      removed = await _notifier.delete(n.id);
    } catch (e) {
      _showError(e);
      return;
    }
    if (removed == null || !mounted) return;
    showDentraSnack(
      context,
      'Notification deleted.',
      tone: DentraFeedbackTone.info,
      retryLabel: 'Undo',
      onRetry: () async {
        try {
          await _notifier.restore(removed!);
        } catch (e) {
          _showError(e);
        }
      },
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.delete_sweep_outlined,
      title: 'Delete all notifications?',
      message: "This can't be undone. Your screenings and account aren't "
          'affected.',
      confirmLabel: 'Delete all',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _notifier.clearAll();
      if (mounted) showDentraSnack(context, 'All notifications deleted.');
    } catch (e) {
      _showError(e, onRetry: _clearAll);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (_navigating) return;
    _navigating = true;
    try {
      // Opening counts as reading. A failed save is not worth blocking the
      // detail for; the row simply stays unread.
      if (!n.isRead) unawaited(_notifier.setRead(n.id).catchError((_) {}));

      final action = await showNotificationDetailSheet(context, n);
      if (!mounted || action == null) return;
      switch (action) {
        case NotificationDetailAction.open:
          await _openTarget(n);
        case NotificationDetailAction.markUnread:
          await _toggleRead(n.withRead(true));
        case NotificationDetailAction.delete:
          await _delete(n);
      }
    } finally {
      _navigating = false;
    }
  }

  Future<void> _openTarget(AppNotification n) async {
    switch (n.target) {
      case NotificationTarget.none:
        return;
      case NotificationTarget.profile:
        Navigator.of(context).pop(NotificationTarget.profile);
      case NotificationTarget.screening:
        final sessionId = n.sessionId;
        List<ScreeningSession>? sessions;
        try {
          sessions = await ref.read(screeningSessionsProvider.future);
        } catch (_) {}
        if (!mounted) return;
        final exists = sessions?.any((s) => s.id == sessionId) ?? false;
        if (sessionId == null || !exists) {
          showDentraSnack(
            context,
            sessions == null
                ? "Your screening history couldn't be loaded."
                : 'That screening is no longer in your history.',
            tone: DentraFeedbackTone.info,
          );
          return;
        }
        await Navigator.of(context)
            .push(ScreeningDetailScreen.route(sessionId));
    }
  }

  Future<void> _signInAgain() async {
    await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final feed = async.valueOrNull;
    final initialLoad = async.isLoading && feed == null;

    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DentraPageHeader(
                title: 'Notifications',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: _HeaderActions(
                  unreadCount: feed?.unreadCount ?? 0,
                  hasItems: feed?.items.isNotEmpty ?? false,
                  markingAll: feed?.markingAll ?? false,
                  onMarkAllRead: _markAllRead,
                  onClearAll: _clearAll,
                ),
                bottom: _FilterBar(
                  selected: feed?.filter ?? NotificationFilter.all,
                  unreadCount: feed?.unreadCount ?? 0,
                  onSelected: initialLoad ? null : _notifier.setFilter,
                ),
              ),
              Divider(height: 1, thickness: 1, color: AppGlass.divider),
              Expanded(
                child: AnimatedSwitcher(
                  duration: dentraMotion(context, 200),
                  child: _body(async),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncValue<NotificationFeed> async) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final padding = EdgeInsets.fromLTRB(
      AppSpacing.screenH,
      16,
      AppSpacing.screenH,
      24 + bottomInset,
    );

    // Loading the first page, or a different filter.
    if (async.isLoading) {
      return ListView(
        key: const ValueKey('loading'),
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        children: const [NotificationSkeleton()],
      );
    }

    final feed = async.valueOrNull;
    if (async.hasError || feed == null) {
      final error = async.error;
      return NotificationErrorState(
        key: const ValueKey('error'),
        failure: error is NotificationException
            ? error.failure
            : NotificationFailure.server,
        onRetry: _notifier.reload,
        onSignIn: _signInAgain,
      );
    }

    return RefreshIndicator(
      key: ValueKey('list-${feed.filter.name}'),
      color: AppColors.g2,
      backgroundColor: AppColors.white,
      onRefresh: _notifier.refresh,
      child: feed.items.isEmpty
          ? _EmptyScroll(
              feed: feed, padding: padding, onRetry: _notifier.refresh)
          : _FeedList(
              feed: feed,
              now: _now,
              padding: padding,
              onTap: _open,
              onToggleRead: _toggleRead,
              onDelete: _delete,
              onRetryRefresh: _notifier.refresh,
              onLoadMore: _notifier.loadMore,
            ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.unreadCount,
    required this.hasItems,
    required this.markingAll,
    required this.onMarkAllRead,
    required this.onClearAll,
  });

  final int unreadCount;
  final bool hasItems;
  final bool markingAll;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: AppColors.white.withValues(alpha: 0.7),
      foregroundColor: AppColors.navy,
      disabledBackgroundColor: AppColors.white.withValues(alpha: 0.35),
      disabledForegroundColor: AppColors.navy.withValues(alpha: 0.3),
      fixedSize: const Size(44, 44),
      minimumSize: const Size(44, 44),
      side: const BorderSide(color: AppGlass.border),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: unreadCount == 0 || markingAll ? null : onMarkAllRead,
          tooltip: 'Mark all as read',
          style: buttonStyle,
          icon: markingAll
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.g2,
                  ),
                )
              : const Icon(Icons.done_all_rounded, size: 20),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'More options',
          enabled: hasItems,
          position: PopupMenuPosition.under,
          color: AppColors.white.withValues(alpha: 0.97),
          elevation: 6,
          shadowColor: AppColors.navy.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppGlass.divider),
          ),
          onSelected: (_) => onClearAll(),
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              value: 'clear',
              height: 48,
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_sweep_outlined,
                    size: 20,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete all',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
          style: buttonStyle,
          icon: const Icon(Icons.more_horiz_rounded, size: 20),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.unreadCount,
    required this.onSelected,
  });

  final NotificationFilter selected;
  final int unreadCount;

  /// Null while the first page loads.
  final ValueChanged<NotificationFilter>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      // Bleeds to the screen edges so chips scroll under the margins.
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: NotificationFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final filter = NotificationFilter.values[i];
          final label = filter == NotificationFilter.unread && unreadCount > 0
              ? 'Unread · ${unreadCount > 99 ? '99+' : unreadCount}'
              : filter.label;
          return Center(
            child: DentraChoiceChip(
              label: label,
              selected: filter == selected,
              onSelected: onSelected == null ? null : () => onSelected!(filter),
            ),
          );
        },
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────

/// A date bucket in the list.
class _Section {
  _Section(this.title);

  final String title;
  final List<AppNotification> items = [];
}

List<_Section> _group(List<AppNotification> items, DateTime now) {
  final today = DentraDates.dateOnly(now);
  final sections = <_Section>[];
  for (final n in items) {
    final days = today.difference(DentraDates.dateOnly(n.createdAt)).inDays;
    final title = switch (days) {
      <= 0 => 'Today',
      1 => 'Yesterday',
      < 7 => 'This week',
      _ => 'Earlier',
    };
    if (sections.isEmpty || sections.last.title != title) {
      sections.add(_Section(title));
    }
    sections.last.items.add(n);
  }
  return sections;
}

class _FeedList extends StatelessWidget {
  const _FeedList({
    required this.feed,
    required this.now,
    required this.padding,
    required this.onTap,
    required this.onToggleRead,
    required this.onDelete,
    required this.onRetryRefresh,
    required this.onLoadMore,
  });

  final NotificationFeed feed;
  final DateTime now;
  final EdgeInsets padding;
  final ValueChanged<AppNotification> onTap;
  final ValueChanged<AppNotification> onToggleRead;
  final ValueChanged<AppNotification> onDelete;
  final VoidCallback onRetryRefresh;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final sections = _group(feed.items, now);
    final refreshFailure = feed.refreshFailure;

    final children = <Widget>[
      if (refreshFailure != null) ...[
        NotificationStaleBanner(
          failure: refreshFailure,
          onRetry: onRetryRefresh,
        ),
        const SizedBox(height: 16),
      ],
      for (final section in sections) ...[
        _SectionLabel(section.title),
        const SizedBox(height: 8),
        GlassCard(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              for (var i = 0; i < section.items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 66,
                    color: AppGlass.divider,
                  ),
                NotificationRow(
                  key: ValueKey(section.items[i].id),
                  notification: section.items[i],
                  now: now,
                  busy: feed.busyIds.contains(section.items[i].id),
                  onTap: () => onTap(section.items[i]),
                  onToggleRead: () => onToggleRead(section.items[i]),
                  onDelete: () => onDelete(section.items[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
      _Footer(feed: feed, onLoadMore: onLoadMore),
    ];

    return ListView(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: children,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

/// Loads the next page as soon as it scrolls into view, with a retry
/// when that fails and a quiet end marker once everything is loaded.
class _Footer extends StatelessWidget {
  const _Footer({required this.feed, required this.onLoadMore});

  final NotificationFeed feed;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final failure = feed.loadMoreFailure;
    if (failure != null) {
      return Center(
        child: Column(
          children: [
            Text(
              failure == NotificationFailure.offline
                  ? "You're offline."
                  : "Couldn't load older notifications.",
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
            TextButton(
              onPressed: onLoadMore,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                'Try again',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
    if (feed.hasMore) {
      return _LoadMoreTrigger(onLoadMore: onLoadMore);
    }
    if (feed.items.length < 6) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          "That's everything",
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.secondaryText.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _LoadMoreTrigger extends StatefulWidget {
  const _LoadMoreTrigger({required this.onLoadMore});

  final VoidCallback onLoadMore;

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    // Built only when it nears the viewport, so this is the scroll trigger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.g2,
            semanticsLabel: 'Loading older notifications',
          ),
        ),
      ),
    );
  }
}

/// Empty state that still supports pull to refresh.
class _EmptyScroll extends StatelessWidget {
  const _EmptyScroll({
    required this.feed,
    required this.padding,
    required this.onRetry,
  });

  final NotificationFeed feed;
  final EdgeInsets padding;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = feed.refreshFailure;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - padding.vertical,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (failure != null)
                NotificationStaleBanner(failure: failure, onRetry: onRetry),
              NotificationEmptyState(filter: feed.filter),
            ],
          ),
        ),
      ),
    );
  }
}
