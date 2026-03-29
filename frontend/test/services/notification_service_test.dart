import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/services/base_service.dart';
import 'package:frontend/services/notification_service.dart';

class _FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;
  Object? lastBody;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    lastPath = path;
    return mapper(nextResponse);
  }

  @override
  Future<T> patchJson<T>(
    String path,
    Object? body,
    T Function(dynamic json) mapper,
  ) async {
    lastPath = path;
    lastBody = body;
    return mapper(nextResponse);
  }
}

void main() {
  late _FakeBaseService fakeBaseService;
  late NotificationService notificationService;

  setUp(() {
    fakeBaseService = _FakeBaseService();
    notificationService = NotificationService(fakeBaseService);
  });

  test(
    'getNotifications requests the patient endpoint and maps unread count',
    () async {
      fakeBaseService.nextResponse = <String, dynamic>{
        'notifications': <Map<String, dynamic>>[
          <String, dynamic>{
            'notification_id': 11,
            'title': 'Appointment booked',
            'message': 'Created successfully.',
            'created_at': '2026-03-30T10:00:00Z',
            'is_read': false,
            'type': 'appointment_created',
            'related_appointment_id': 5,
          },
        ],
        'unread_count': 1,
      };

      final NotificationListResult result = await notificationService
          .getNotifications('patient');

      expect(fakeBaseService.lastPath, '/api/v1/patient/notifications');
      expect(result.unreadCount, 1);
      expect(result.notifications, hasLength(1));
      expect(result.notifications.single.id, 11);
      expect(result.notifications.single.isRead, isFalse);
    },
  );

  test('markAsRead requests the staff mark-read endpoint', () async {
    fakeBaseService.nextResponse = <String, dynamic>{
      'notification': <String, dynamic>{
        'notification_id': 24,
        'title': 'Queue update',
        'message': 'Please check the desk.',
        'created_at': '2026-03-30T10:30:00Z',
        'is_read': true,
        'type': 'queue',
      },
    };

    final AppNotification result = await notificationService.markAsRead(
      'staff',
      24,
    );

    expect(fakeBaseService.lastPath, '/api/v1/staff/notifications/24/read');
    expect(fakeBaseService.lastBody, <String, dynamic>{});
    expect(result.id, 24);
    expect(result.isRead, isTrue);
  });

  test('markAllAsRead requests the patient bulk-read endpoint', () async {
    fakeBaseService.nextResponse = <String, dynamic>{
      'updated_count': 3,
      'unread_count': 0,
    };

    final int updatedCount = await notificationService.markAllAsRead('patient');

    expect(fakeBaseService.lastPath, '/api/v1/patient/notifications/read-all');
    expect(fakeBaseService.lastBody, <String, dynamic>{});
    expect(updatedCount, 3);
  });
}
