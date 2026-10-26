/// An in-app notification shown in the notification center.
///
/// JSON keys match the `notifications` table in `database/schema.sql`, so
/// the same shape serves the local store and the future API.
class AppNotification {
  /// Stable id. Events use deterministic ids (e.g. `scan-<sessionId>`), so
  /// emitting the same event twice never creates a duplicate.
  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Null while unread.
  final DateTime? readAt;

  /// Where tapping the notification's action leads.
  final NotificationTarget target;

  /// Screening this notification refers to, for [NotificationTarget.screening].
  final String? sessionId;

  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.target = NotificationTarget.none,
    this.sessionId,
  });

  bool get isRead => readAt != null;

  AppNotification withRead(bool read, [DateTime? at]) => AppNotification(
        id: id,
        category: category,
        title: title,
        body: body,
        createdAt: createdAt,
        readAt: read ? (readAt ?? at ?? DateTime.now()) : null,
        target: target,
        sessionId: sessionId,
      );

  /// Newest first; ties broken by id so paging is stable.
  static int newestFirst(AppNotification a, AppNotification b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'title': title,
        'body': body,
        'created_at': createdAt.toUtc().toIso8601String(),
        'read_at': readAt?.toUtc().toIso8601String(),
        'target': target.name,
        'session_id': sessionId,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final readAt = json['read_at'] as String?;
    final sessionId = json['session_id'] as String?;
    return AppNotification(
      id: json['id'] as String,
      category: NotificationCategory.parse(
        (json['category'] ?? json['kind']) as String?,
      ),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      readAt: readAt == null ? null : DateTime.tryParse(readAt)?.toLocal(),
      target: NotificationTarget.values.asNameMap()[json['target']] ??
          (sessionId != null
              ? NotificationTarget.screening
              : NotificationTarget.none),
      sessionId: sessionId,
    );
  }
}

/// What a notification is about. Drives its icon, accent and filter.
enum NotificationCategory {
  screening('Screenings', 'Screening'),
  account('Account', 'Account'),
  security('Security', 'Security'),
  system('Announcements', 'Announcement');

  const NotificationCategory(this.pluralLabel, this.label);

  /// Filter chip label.
  final String pluralLabel;

  /// Label shown on a single notification.
  final String label;

  /// Unknown values from newer app versions load as [system]. Also maps
  /// the kinds used by the first local release.
  static NotificationCategory parse(String? raw) => switch (raw) {
        'analysis' => screening,
        'reminder' => system,
        _ => values.asNameMap()[raw] ?? system,
      };
}

/// Destination of a notification's action.
enum NotificationTarget {
  none,

  /// The screening in [AppNotification.sessionId].
  screening,

  /// The Profile tab (account details, password, two-factor).
  profile,
}
