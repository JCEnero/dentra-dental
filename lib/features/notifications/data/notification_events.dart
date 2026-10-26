import 'models/app_notification.dart';

/// Notifications the app raises for real events. Each is built from what
/// actually happened; nothing here is sample data.
///
/// Ids are deterministic per event so a retried or repeated emit is
/// stored once.
abstract class NotificationEvents {
  /// A new account was created.
  static AppNotification welcome() => AppNotification(
        id: 'welcome',
        category: NotificationCategory.system,
        title: 'Welcome to DENTRA',
        body: 'Scan results, account changes and security alerts will '
            'appear here.',
        createdAt: DateTime.now(),
      );

  static AppNotification passwordChanged() {
    final now = DateTime.now();
    return AppNotification(
      id: 'password-${now.microsecondsSinceEpoch}',
      category: NotificationCategory.security,
      title: 'Password changed',
      body: "Your password was changed. If you didn't do this, reset your "
          'password right away.',
      createdAt: now,
      target: NotificationTarget.profile,
    );
  }

  static AppNotification twoFactorChanged({required bool enabled}) {
    final now = DateTime.now();
    return AppNotification(
      id: '2fa-${enabled ? 'on' : 'off'}-${now.microsecondsSinceEpoch}',
      category: NotificationCategory.security,
      title: enabled
          ? 'Two-factor authentication on'
          : 'Two-factor authentication off',
      body: enabled
          ? 'Signing in now needs a code sent to your email.'
          : "Signing in only needs your password. If you didn't turn "
              'this off, secure your account.',
      createdAt: now,
      target: NotificationTarget.profile,
    );
  }

  static AppNotification profileUpdated() {
    final now = DateTime.now();
    return AppNotification(
      id: 'profile-${now.microsecondsSinceEpoch}',
      category: NotificationCategory.account,
      title: 'Profile updated',
      body: 'Your personal details were saved.',
      createdAt: now,
      target: NotificationTarget.profile,
    );
  }

  /// A finished scan was saved to history.
  static AppNotification screeningSaved({
    required String sessionId,
    required int captured,
    required int total,
  }) {
    final complete = captured >= total;
    return AppNotification(
      id: 'scan-$sessionId',
      category: NotificationCategory.screening,
      title: complete ? 'Screening saved' : 'Partial screening saved',
      body: complete
          ? 'All $total regions were captured. Review your photos anytime.'
          : '$captured of $total regions captured. You can scan the rest '
              'anytime.',
      createdAt: DateTime.now(),
      target: NotificationTarget.screening,
      sessionId: sessionId,
    );
  }

  /// The AI analysis for a saved scan is ready.
  static AppNotification analysisReady({required String sessionId}) =>
      AppNotification(
        id: 'analysis-$sessionId',
        category: NotificationCategory.screening,
        title: 'Screening results ready',
        body: 'Your screening summary is available. It is not a diagnosis; '
            'share it with your dentist.',
        createdAt: DateTime.now(),
        target: NotificationTarget.screening,
        sessionId: sessionId,
      );
}
