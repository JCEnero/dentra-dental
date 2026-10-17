import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_notification.dart';

/// Why a notification request failed. Screens map this to a message.
enum NotificationFailure {
  /// No connection or the request timed out.
  offline,

  /// The session expired or the user no longer has access (HTTP 401/403).
  unauthorized,

  /// The service answered with an error (HTTP 5xx, malformed response).
  server,

  /// On-device storage could not be read or written.
  storage,
}

class NotificationException implements Exception {
  const NotificationException(this.failure);

  final NotificationFailure failure;

  @override
  String toString() => 'NotificationException(${failure.name})';
}

/// One page of notifications, newest first.
class NotificationPage {
  const NotificationPage({required this.items, required this.hasMore});

  final List<AppNotification> items;
  final bool hasMore;
}

/// Server-side filter for a notification list.
class NotificationQuery {
  const NotificationQuery({this.unreadOnly = false, this.category});

  final bool unreadOnly;
  final NotificationCategory? category;

  bool matches(AppNotification n) =>
      (!unreadOnly || !n.isRead) &&
      (category == null || n.category == category);

  @override
  bool operator ==(Object other) =>
      other is NotificationQuery &&
      other.unreadOnly == unreadOnly &&
      other.category == category;

  @override
  int get hashCode => Object.hash(unreadOnly, category);
}

/// Data access for in-app notifications. Every call is scoped to one user.
///
/// Screens and providers only use this interface. [LocalNotificationRepository]
/// backs it today; when the backend is live, add an API-backed
/// implementation and swap it in `notificationRepositoryProvider`. It
/// should throw [NotificationException] with the matching
/// [NotificationFailure] so the screens can explain what went wrong.
///
/// Suggested endpoints (table `notifications` in `database/schema.sql`;
/// the API takes the user from the auth token, never from the client):
///   GET    /me/notifications?before=<created_at>,<id>&limit=20
///          &unread=true&category=security
///   GET    /me/notifications/unread-count
///   PUT    /me/notifications/{id}          (create, idempotent on id)
///   PATCH  /me/notifications/{id}          {"read": true|false}
///   POST   /me/notifications/read-all
///   DELETE /me/notifications/{id}
///   DELETE /me/notifications
abstract class NotificationRepository {
  /// Up to [limit] notifications older than [after] (exclusive), newest
  /// first. Pass no [after] for the first page.
  Future<NotificationPage> fetchPage(
    String userId, {
    NotificationQuery query = const NotificationQuery(),
    AppNotification? after,
    int limit = 20,
  });

  Future<int> unreadCount(String userId);

  /// Stores [notification] unless one with the same id exists. Returns
  /// whether it was created, so callers never count a duplicate.
  Future<bool> create(String userId, AppNotification notification);

  Future<void> setRead(String userId, String id, {required bool read});

  Future<void> markAllRead(String userId);

  Future<void> delete(String userId, String id);

  Future<void> deleteAll(String userId);
}

/// Device-local [NotificationRepository] backed by SharedPreferences.
class LocalNotificationRepository implements NotificationRepository {
  static String _key(String userId) => 'notifications.v1.$userId';

  /// Oldest entries are dropped beyond this, to keep storage small.
  static const maxStored = 200;

  // Writes are read-modify-write; run them one at a time so two quick
  // events can't overwrite each other.
  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<NotificationPage> fetchPage(
    String userId, {
    NotificationQuery query = const NotificationQuery(),
    AppNotification? after,
    int limit = 20,
  }) async {
    final all = (await _read(userId)).where(query.matches);
    final older = after == null
        ? all
        : all.where((n) => AppNotification.newestFirst(after, n) < 0);
    final page = older.take(limit + 1).toList();
    return NotificationPage(
      items: page.take(limit).toList(),
      hasMore: page.length > limit,
    );
  }

  @override
  Future<int> unreadCount(String userId) async =>
      (await _read(userId)).where((n) => !n.isRead).length;

  @override
  Future<bool> create(String userId, AppNotification notification) =>
      _serial(() async {
        final current = await _read(userId);
        if (current.any((n) => n.id == notification.id)) return false;
        final next = [notification, ...current]
          ..sort(AppNotification.newestFirst);
        await _write(userId, next.take(maxStored).toList());
        return true;
      });

  @override
  Future<void> setRead(String userId, String id, {required bool read}) =>
      _serial(() async {
        final now = DateTime.now();
        final current = await _read(userId);
        await _write(userId, [
          for (final n in current) n.id == id ? n.withRead(read, now) : n,
        ]);
      });

  @override
  Future<void> markAllRead(String userId) => _serial(() async {
        final now = DateTime.now();
        final current = await _read(userId);
        await _write(userId, [for (final n in current) n.withRead(true, now)]);
      });

  @override
  Future<void> delete(String userId, String id) => _serial(() async {
        final current = await _read(userId);
        await _write(userId, current.where((n) => n.id != id).toList());
      });

  @override
  Future<void> deleteAll(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {
      throw const NotificationException(NotificationFailure.storage);
    }
  }

  Future<List<AppNotification>> _read(String userId) async {
    final String? raw;
    try {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_key(userId));
    } catch (_) {
      throw const NotificationException(NotificationFailure.storage);
    }
    if (raw == null) return [];
    final list = <AppNotification>[];
    try {
      for (final e in jsonDecode(raw) as List<dynamic>) {
        // Skip a malformed record rather than losing the whole list.
        try {
          list.add(AppNotification.fromJson(e as Map<String, dynamic>));
        } catch (_) {}
      }
    } catch (_) {
      throw const NotificationException(NotificationFailure.storage);
    }
    return list..sort(AppNotification.newestFirst);
  }

  Future<void> _write(String userId, List<AppNotification> items) async {
    bool ok;
    try {
      final prefs = await SharedPreferences.getInstance();
      ok = await prefs.setString(
        _key(userId),
        jsonEncode(items.map((n) => n.toJson()).toList()),
      );
    } catch (_) {
      ok = false;
    }
    if (!ok) throw const NotificationException(NotificationFailure.storage);
  }
}
