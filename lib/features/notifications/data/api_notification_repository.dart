import 'dart:async';

import '../../../core/network/api_client.dart';
import 'models/app_notification.dart';
import 'notification_repository.dart';

/// [NotificationRepository] backed by the DENTRA API
/// (`/api/notifications`). The server scopes every call to the token's
/// user, so [userId] arguments are only kept for the interface.
class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<NotificationPage> fetchPage(
    String userId, {
    NotificationQuery query = const NotificationQuery(),
    AppNotification? after,
    int limit = 20,
  }) async {
    final body = await _call(() => _api.send('GET', '/api/notifications', query: {
          'limit': '$limit',
          if (query.unreadOnly) 'unread': 'true',
          if (query.category != null) 'category': query.category!.name,
          // Keyset cursor: the last notification already loaded.
          if (after != null) ...{
            'before_created_at': after.createdAt.toUtc().toIso8601String(),
            'before_id': after.id,
          },
        }));
    return NotificationPage(
      items: [
        for (final item in body['items'] as List<dynamic>)
          AppNotification.fromJson(item as Map<String, dynamic>),
      ],
      hasMore: body['has_more'] as bool? ?? false,
    );
  }

  @override
  Future<int> unreadCount(String userId) async {
    final body = await _call(
      () => _api.send('GET', '/api/notifications/unread-count'),
    );
    return body['count'] as int? ?? 0;
  }

  @override
  Future<bool> create(String userId, AppNotification notification) async {
    final body = await _call(() => _api.send(
          'PUT',
          '/api/notifications/${Uri.encodeComponent(notification.id)}',
          json: notification.toJson(),
        ));
    return body['created'] as bool? ?? false;
  }

  @override
  Future<void> setRead(String userId, String id, {required bool read}) =>
      _call(() => _api.send(
            'PATCH',
            '/api/notifications/${Uri.encodeComponent(id)}',
            json: {'read': read},
          ));

  @override
  Future<void> markAllRead(String userId) =>
      _call(() => _api.send('POST', '/api/notifications/read-all'));

  @override
  Future<void> delete(String userId, String id) => _call(
        () => _api.send('DELETE', '/api/notifications/${Uri.encodeComponent(id)}'),
      );

  @override
  Future<void> deleteAll(String userId) =>
      _call(() => _api.send('DELETE', '/api/notifications'));

  /// Maps failures to the [NotificationFailure] the screens explain.
  Future<Map<String, dynamic>> _call(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on ApiException catch (e) {
      throw NotificationException(
        e.statusCode == 401 || e.statusCode == 403
            ? NotificationFailure.unauthorized
            : NotificationFailure.server,
      );
    } on FormatException {
      throw const NotificationException(NotificationFailure.server);
    } on TypeError {
      // Response JSON in an unexpected shape.
      throw const NotificationException(NotificationFailure.server);
    } catch (_) {
      throw const NotificationException(NotificationFailure.offline);
    }
  }
}
