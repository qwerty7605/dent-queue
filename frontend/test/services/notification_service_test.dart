import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/short_term_cache.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/services/base_service.dart';
import 'package:frontend/services/notification_service.dart';

class _FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;
  Object? lastBody;
  int getJsonCallCount = 0;
  int patchJsonCallCount = 0;
  Completer<dynamic>? pendingGetJsonResponse;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    getJsonCallCount += 1;
    lastPath = path;
    final dynamic response = pendingGetJsonResponse == null
        ? nextResponse
        : await pendingGetJsonResponse!.future;
    return mapper(response);
  }

  @override
  Future<T> patchJson<T>(
    String path,
    Object? body,
    T Function(dynamic json) mapper,
  ) async {
    patchJsonCallCount += 1;
    lastPath = path;
    lastBody = body;
    return mapper(nextResponse);
  }
}

class _FakeTokenStorage extends Fake implements TokenStorage {
  Map<String, dynamic>? userInfo;

  @override
  Future<Map<String, dynamic>?> readUserInfo() async {
    return userInfo;
  }
}

void main() {
  late _FakeBaseService fakeBaseService;
  late _FakeTokenStorage fakeTokenStorage;
  late NotificationService notificationService;

  setUp(() {
    fakeBaseService = _FakeBaseService();
    fakeTokenStorage = _FakeTokenStorage()
      ..userInfo = <String, dynamic>{'id': 1, 'role': 'patient'};
    notificationService = NotificationService(
      fakeBaseService,
      tokenStorage: fakeTokenStorage,
    );
    ShortTermCache.clear();
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

  test('getNotifications appends force refresh when requested', () async {
    fakeBaseService.nextResponse = <String, dynamic>{
      'notifications': <Map<String, dynamic>>[],
      'unread_count': 0,
    };

    await notificationService.getNotifications('patient', forceRefresh: true);

    expect(
      fakeBaseService.lastPath,
      '/api/v1/patient/notifications?force_refresh=true',
    );
  });

  test(
    'getNotifications uses cache until a read mutation invalidates it',
    () async {
      fakeBaseService.nextResponse = <String, dynamic>{
        'notifications': <Map<String, dynamic>>[
          <String, dynamic>{
            'notification_id': 7,
            'title': 'Reminder',
            'message': 'Upcoming appointment.',
            'created_at': '2026-03-30T10:00:00Z',
            'is_read': false,
            'type': 'reminder',
          },
        ],
        'unread_count': 1,
      };

      final NotificationListResult first = await notificationService
          .getNotifications('patient');
      final NotificationListResult second = await notificationService
          .getNotifications('patient');

      expect(first.notifications, hasLength(1));
      expect(second.notifications, hasLength(1));
      expect(fakeBaseService.getJsonCallCount, 1);

      fakeBaseService.nextResponse = <String, dynamic>{
        'notification': <String, dynamic>{
          'notification_id': 7,
          'title': 'Reminder',
          'message': 'Upcoming appointment.',
          'created_at': '2026-03-30T10:00:00Z',
          'is_read': true,
          'type': 'reminder',
        },
      };
      await notificationService.markAsRead('patient', 7);

      fakeBaseService.nextResponse = <String, dynamic>{
        'notifications': <Map<String, dynamic>>[],
        'unread_count': 0,
      };
      await notificationService.getNotifications('patient');

      expect(fakeBaseService.getJsonCallCount, 2);
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

  test('getNotifications caches results separately per user', () async {
    fakeBaseService.nextResponse = <String, dynamic>{
      'notifications': <Map<String, dynamic>>[
        <String, dynamic>{
          'notification_id': 17,
          'title': 'Patient one',
          'message': 'First user notification.',
          'created_at': '2026-03-30T10:00:00Z',
          'is_read': false,
          'type': 'queue',
        },
      ],
      'unread_count': 1,
    };

    final NotificationListResult first = await notificationService
        .getNotifications('patient');

    fakeTokenStorage.userInfo = <String, dynamic>{'id': 2, 'role': 'patient'};
    fakeBaseService.nextResponse = <String, dynamic>{
      'notifications': <Map<String, dynamic>>[
        <String, dynamic>{
          'notification_id': 23,
          'title': 'Patient two',
          'message': 'Second user notification.',
          'created_at': '2026-03-30T11:00:00Z',
          'is_read': false,
          'type': 'queue',
        },
      ],
      'unread_count': 1,
    };

    final NotificationListResult second = await notificationService
        .getNotifications('patient');

    expect(first.notifications.single.id, 17);
    expect(second.notifications.single.id, 23);
    expect(fakeBaseService.getJsonCallCount, 2);
  });

  test('markAllAsRead invalidates cached notifications', () async {
    fakeBaseService.nextResponse = <String, dynamic>{
      'notifications': <Map<String, dynamic>>[
        <String, dynamic>{
          'notification_id': 9,
          'title': 'Reminder',
          'message': 'Unread before mark all.',
          'created_at': '2026-03-30T10:00:00Z',
          'is_read': false,
          'type': 'reminder',
        },
      ],
      'unread_count': 1,
    };

    await notificationService.getNotifications('patient');
    expect(fakeBaseService.getJsonCallCount, 1);

    fakeBaseService.nextResponse = <String, dynamic>{
      'updated_count': 1,
      'unread_count': 0,
    };
    await notificationService.markAllAsRead('patient');

    fakeBaseService.nextResponse = <String, dynamic>{
      'notifications': <Map<String, dynamic>>[],
      'unread_count': 0,
    };
    final NotificationListResult refreshed = await notificationService
        .getNotifications('patient');

    expect(fakeBaseService.patchJsonCallCount, 1);
    expect(fakeBaseService.getJsonCallCount, 2);
    expect(refreshed.unreadCount, 0);
    expect(refreshed.notifications, isEmpty);
  });

  test('getNotifications collapses concurrent matching requests', () async {
    fakeBaseService.pendingGetJsonResponse = Completer<dynamic>();

    final Future<NotificationListResult> first = notificationService
        .getNotifications('patient');
    final Future<NotificationListResult> second = notificationService
        .getNotifications('patient');

    await Future<void>.delayed(Duration.zero);

    expect(fakeBaseService.getJsonCallCount, 1);

    fakeBaseService.pendingGetJsonResponse!.complete(<String, dynamic>{
      'notifications': <Map<String, dynamic>>[
        <String, dynamic>{
          'notification_id': 12,
          'title': 'Queue update',
          'message': 'A queue slot was assigned.',
          'created_at': '2026-03-30T10:00:00Z',
          'is_read': false,
          'type': 'queue',
        },
      ],
      'unread_count': 1,
    });

    final List<NotificationListResult> results =
        await Future.wait<NotificationListResult>(
          <Future<NotificationListResult>>[first, second],
        );

    expect(results[0].notifications, hasLength(1));
    expect(results[1].notifications, hasLength(1));
    expect(results[0].unreadCount, 1);
    expect(results[1].unreadCount, 1);
  });
}
