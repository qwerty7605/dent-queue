import '../core/endpoints.dart';
import '../models/app_notification.dart';
import 'base_service.dart';

class NotificationListResult {
  const NotificationListResult({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
}

class NotificationService {
  NotificationService(this._baseService);

  final BaseService _baseService;

  Future<NotificationListResult> getNotifications(String role) async {
    final response = await _baseService.getJson<dynamic>(
      _notificationsPath(role),
      (data) => data,
    );

    if (response is! Map<String, dynamic>) {
      return const NotificationListResult(
        notifications: <AppNotification>[],
        unreadCount: 0,
      );
    }

    final List<AppNotification> notifications =
        (response['notifications'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((Map<dynamic, dynamic> item) {
              return AppNotification.fromJson(Map<String, dynamic>.from(item));
            })
            .toList();

    final int unreadCount =
        response['unread_count'] as int? ??
        notifications.where((AppNotification notification) {
          return !notification.isRead;
        }).length;

    return NotificationListResult(
      notifications: notifications,
      unreadCount: unreadCount,
    );
  }

  Future<AppNotification> markAsRead(String role, int notificationId) async {
    final response = await _baseService.patchJson<dynamic>(
      _markAsReadPath(role, notificationId),
      <String, dynamic>{},
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['notification'] is Map) {
      return AppNotification.fromJson(
        Map<String, dynamic>.from(response['notification'] as Map),
      );
    }

    throw StateError(
      'Notification read response is missing notification data.',
    );
  }

  Future<int> markAllAsRead(String role) async {
    final response = await _baseService.patchJson<dynamic>(
      _markAllAsReadPath(role),
      <String, dynamic>{},
      (data) => data,
    );

    if (response is Map<String, dynamic>) {
      return response['updated_count'] as int? ?? 0;
    }

    return 0;
  }

  String _notificationsPath(String role) {
    return _normalizedRole(role) == 'staff'
        ? Endpoints.staffNotifications
        : Endpoints.patientNotifications;
  }

  String _markAsReadPath(String role, int notificationId) {
    return _normalizedRole(role) == 'staff'
        ? Endpoints.staffNotificationMarkRead(notificationId)
        : Endpoints.patientNotificationMarkRead(notificationId);
  }

  String _markAllAsReadPath(String role) {
    return _normalizedRole(role) == 'staff'
        ? Endpoints.staffNotificationsMarkAllRead
        : Endpoints.patientNotificationsMarkAllRead;
  }

  String _normalizedRole(String role) {
    final String normalized = role.trim().toLowerCase();

    if (normalized == 'staff' || normalized == 'admin') {
      return 'staff';
    }

    return 'patient';
  }
}
