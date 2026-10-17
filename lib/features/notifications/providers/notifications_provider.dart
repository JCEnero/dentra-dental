import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/api_notification_repository.dart';
import '../data/models/app_notification.dart';
import '../data/notification_repository.dart';

/// Backend for notifications. Override in tests.
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  // The DENTRA API when configured, the on-device store otherwise.
  final api = ref.watch(apiClientProvider);
  return api == null
      ? LocalNotificationRepository()
      : ApiNotificationRepository(api);
});

/// Quick filters on the notification screen.
enum NotificationFilter {
  all(NotificationQuery()),
  unread(NotificationQuery(unreadOnly: true)),
  screening(NotificationQuery(category: NotificationCategory.screening)),
  account(NotificationQuery(category: NotificationCategory.account)),
  security(NotificationQuery(category: NotificationCategory.security)),
  system(NotificationQuery(category: NotificationCategory.system));

  const NotificationFilter(this.query);
  final NotificationQuery query;

  String get label => switch (this) {
        all => 'All',
        unread => 'Unread',
        _ => query.category!.pluralLabel,
      };
}

/// What the notification screen shows: the loaded pages for the current
/// filter, plus the user's total unread count across all notifications.
class NotificationFeed {
  const NotificationFeed({
    this.items = const [],
    this.filter = NotificationFilter.all,
    this.hasMore = false,
    this.unreadCount = 0,
    this.loadingMore = false,
    this.loadMoreFailure,
    this.refreshFailure,
    this.busyIds = const {},
    this.markingAll = false,
  });

  final List<AppNotification> items;
  final NotificationFilter filter;
  final bool hasMore;
  final int unreadCount;
  final bool loadingMore;

  /// Set when the next page failed to load; the footer offers a retry.
  final NotificationFailure? loadMoreFailure;

  /// Set when a refresh failed while older data is still on screen.
  final NotificationFailure? refreshFailure;

  /// Notifications with a request in flight; their actions are disabled.
  final Set<String> busyIds;
  final bool markingAll;

  NotificationFeed copyWith({
    List<AppNotification>? items,
    NotificationFilter? filter,
    bool? hasMore,
    int? unreadCount,
    bool? loadingMore,
    NotificationFailure? Function()? loadMoreFailure,
    NotificationFailure? Function()? refreshFailure,
    Set<String>? busyIds,
    bool? markingAll,
  }) {
    return NotificationFeed(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailure:
          loadMoreFailure != null ? loadMoreFailure() : this.loadMoreFailure,
      refreshFailure:
          refreshFailure != null ? refreshFailure() : this.refreshFailure,
      busyIds: busyIds ?? this.busyIds,
      markingAll: markingAll ?? this.markingAll,
    );
  }
}

/// The signed-in user's notifications. Reloads when the user changes, so
/// one account never sees another's list.
///
/// User actions update the screen first, then roll back and rethrow a
/// [NotificationException] if the request fails, so the caller can explain.
class NotificationsNotifier extends AsyncNotifier<NotificationFeed> {
  // Used when the app is opened without a session (e.g. during development).
  static const _guestId = 'guest';
  static const pageSize = 20;

  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);
  String _userId = _guestId;
  NotificationFilter _filter = NotificationFilter.all;

  // Bumped on every reload so a slow, stale page can't land on a new list.
  int _generation = 0;

  @override
  Future<NotificationFeed> build() async {
    _userId = ref.watch(authServiceProvider.select((a) => a.currentUserId)) ??
        _guestId;
    // The build result always lands, so it is never treated as superseded.
    return _load(_filter, guard: false);
  }

  Future<NotificationFeed> _load(
    NotificationFilter filter, {
    bool guard = true,
  }) async {
    final generation = ++_generation;
    try {
      final results = await Future.wait([
        _repo.fetchPage(_userId, query: filter.query, limit: pageSize),
        _repo.unreadCount(_userId),
      ]);
      if (guard && generation != _generation) throw const _Superseded();
      final page = results[0] as NotificationPage;
      return NotificationFeed(
        items: page.items,
        filter: filter,
        hasMore: page.hasMore,
        unreadCount: results[1] as int,
      );
    } on NotificationException {
      rethrow;
    } on _Superseded {
      rethrow;
    } catch (_) {
      throw const NotificationException(NotificationFailure.server);
    }
  }

  /// Switches the filter and loads its first page.
  Future<void> setFilter(NotificationFilter filter) async {
    if (filter == _filter && state.hasValue && !state.hasError) return;
    _filter = filter;
    await reload();
  }

  /// Shows the loading state and loads the first page again, e.g. from a
  /// retry button. The previous list (with the new filter) stays readable
  /// by widgets that want it.
  Future<void> reload() async {
    final filter = _filter;
    final previous = state.valueOrNull;
    state = previous == null
        ? const AsyncLoading<NotificationFeed>()
        : const AsyncLoading<NotificationFeed>().copyWithPrevious(
            AsyncData(previous.copyWith(filter: filter)),
          );
    try {
      state = AsyncData(await _load(filter));
    } on _Superseded {
      // A newer request owns the state.
    } catch (e, st) {
      state = AsyncError<NotificationFeed>(e, st);
    }
  }

  /// Reloads the first page. If it fails while a list is on screen, the
  /// list stays and [NotificationFeed.refreshFailure] is set instead.
  Future<void> refresh() async {
    final previous = state.valueOrNull;
    try {
      state = AsyncData(await _load(_filter));
    } on _Superseded {
      // A newer request owns the state.
    } on NotificationException catch (e, st) {
      state = previous != null
          ? AsyncData(previous.copyWith(refreshFailure: () => e.failure))
          : AsyncError<NotificationFeed>(e, st);
    }
  }

  /// Loads the next page. Safe to call repeatedly while scrolling.
  Future<void> loadMore() async {
    final feed = state.valueOrNull;
    if (feed == null || !feed.hasMore || feed.loadingMore) return;
    if (feed.items.isEmpty) return;
    final generation = _generation;
    state = AsyncData(feed.copyWith(
      loadingMore: true,
      loadMoreFailure: () => null,
    ));
    try {
      final page = await _repo.fetchPage(
        _userId,
        query: feed.filter.query,
        after: feed.items.last,
        limit: pageSize,
      );
      if (generation != _generation) return;
      final current = state.valueOrNull ?? feed;
      final known = current.items.map((n) => n.id).toSet();
      state = AsyncData(current.copyWith(
        items: [
          ...current.items,
          ...page.items.where((n) => !known.contains(n.id)),
        ],
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (e) {
      if (generation != _generation) return;
      final current = state.valueOrNull ?? feed;
      state = AsyncData(current.copyWith(
        loadingMore: false,
        loadMoreFailure: () => _failureOf(e),
      ));
    }
  }

  /// Marks one notification read or unread.
  Future<void> setRead(String id, {bool read = true}) async {
    final feed = state.valueOrNull;
    final target = feed?.items.where((n) => n.id == id).firstOrNull;
    if (feed == null || target == null) return;
    if (target.isRead == read || feed.busyIds.contains(id)) return;

    _apply((f) => f.copyWith(
          items: [for (final n in f.items) n.id == id ? n.withRead(read) : n],
          unreadCount: (f.unreadCount + (read ? -1 : 1)).clamp(0, 1 << 30),
          busyIds: {...f.busyIds, id},
        ));
    try {
      await _repo.setRead(_userId, id, read: read);
      _apply((f) => f.copyWith(busyIds: {...f.busyIds}..remove(id)));
    } catch (e) {
      _apply((f) => f.copyWith(
            items: [for (final n in f.items) n.id == id ? target : n],
            unreadCount: (f.unreadCount + (read ? 1 : -1)).clamp(0, 1 << 30),
            busyIds: {...f.busyIds}..remove(id),
          ));
      throw NotificationException(_failureOf(e));
    }
  }

  Future<void> markAllRead() async {
    final feed = state.valueOrNull;
    if (feed == null || feed.markingAll || feed.unreadCount == 0) return;
    final now = DateTime.now();
    _apply((f) => f.copyWith(
          items: [for (final n in f.items) n.withRead(true, now)],
          unreadCount: 0,
          markingAll: true,
        ));
    try {
      await _repo.markAllRead(_userId);
      _apply((f) => f.copyWith(markingAll: false));
    } catch (e) {
      state = AsyncData(feed);
      throw NotificationException(_failureOf(e));
    }
  }

  /// Removes one notification. Returns it so the caller can offer undo.
  Future<AppNotification?> delete(String id) async {
    final feed = state.valueOrNull;
    final target = feed?.items.where((n) => n.id == id).firstOrNull;
    if (feed == null || target == null || feed.busyIds.contains(id)) {
      return null;
    }
    _apply((f) => f.copyWith(
          items: f.items.where((n) => n.id != id).toList(),
          unreadCount: target.isRead ? f.unreadCount : f.unreadCount - 1,
          busyIds: {...f.busyIds, id},
        ));
    try {
      await _repo.delete(_userId, id);
      _apply((f) => f.copyWith(busyIds: {...f.busyIds}..remove(id)));
      return target;
    } catch (e) {
      _apply((f) => f.copyWith(
            items: [...f.items, target]..sort(AppNotification.newestFirst),
            unreadCount: target.isRead ? f.unreadCount : f.unreadCount + 1,
            busyIds: {...f.busyIds}..remove(id),
          ));
      throw NotificationException(_failureOf(e));
    }
  }

  /// Puts back a notification removed with [delete].
  Future<void> restore(AppNotification notification) async {
    try {
      await _repo.create(_userId, notification);
    } catch (e) {
      throw NotificationException(_failureOf(e));
    }
    _insert(notification);
  }

  Future<void> clearAll() async {
    final feed = state.valueOrNull;
    if (feed == null) return;
    _apply((f) => f.copyWith(items: const [], unreadCount: 0, hasMore: false));
    try {
      await _repo.deleteAll(_userId);
    } catch (e) {
      state = AsyncData(feed);
      throw NotificationException(_failureOf(e));
    }
  }

  /// Records an app event. Best-effort: a storage failure must never
  /// break the flow that raised it, so errors are swallowed. Duplicates
  /// (same id) are ignored.
  Future<void> record(AppNotification notification) async {
    // Resolve the owner now, not later: the event belongs to whoever is
    // signed in when it happened.
    final userId = ref.read(authServiceProvider).currentUserId ?? _guestId;
    try {
      final created = await _repo.create(userId, notification);
      if (created && userId == _userId) _insert(notification);
    } catch (_) {}
  }

  void _insert(AppNotification n) {
    final feed = state.valueOrNull;
    if (feed == null || feed.items.any((e) => e.id == n.id)) return;
    final visible = feed.filter.query.matches(n);
    // Past the loaded pages: it will arrive with a later page instead.
    final beyondLoaded = feed.hasMore &&
        feed.items.isNotEmpty &&
        AppNotification.newestFirst(feed.items.last, n) < 0;
    state = AsyncData(feed.copyWith(
      items: visible && !beyondLoaded
          ? ([...feed.items, n]..sort(AppNotification.newestFirst))
          : null,
      unreadCount: n.isRead ? null : feed.unreadCount + 1,
    ));
  }

  void _apply(NotificationFeed Function(NotificationFeed) update) {
    final feed = state.valueOrNull;
    if (feed != null) state = AsyncData(update(feed));
  }

  static NotificationFailure _failureOf(Object e) =>
      e is NotificationException ? e.failure : NotificationFailure.server;
}

class _Superseded implements Exception {
  const _Superseded();
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationFeed>(
  NotificationsNotifier.new,
);

/// Unread notifications across all categories. 0 while loading or on error.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(
    notificationsProvider.select((s) => s.valueOrNull?.unreadCount ?? 0),
  );
});

/// User-facing text for a [NotificationFailure].
String notificationFailureMessage(NotificationFailure failure) =>
    switch (failure) {
      NotificationFailure.offline =>
        "You're offline. Check your connection and try again.",
      NotificationFailure.unauthorized =>
        'Your session has expired. Sign in again to see your notifications.',
      NotificationFailure.server =>
        "DENTRA couldn't load your notifications right now. Try again in a moment.",
      NotificationFailure.storage =>
        "Notifications couldn't be read from this device. Try again.",
    };
