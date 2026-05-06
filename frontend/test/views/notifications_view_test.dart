import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/views/notifications_view.dart';

class _FakeNotificationService extends Fake implements NotificationService {
  NotificationListResult nextResult = const NotificationListResult(
    notifications: <AppNotification>[],
    unreadCount: 0,
  );

  List<NotificationListResult> queuedResults = <NotificationListResult>[];
  final List<int> markedIds = <int>[];
  int markAllCalls = 0;
  int listCalls = 0;
  String? lastListedRole;
  bool lastForceRefresh = false;

  @override
  Future<NotificationListResult?> getCachedNotifications(
    String role, {
    bool allowStale = false,
  }) async {
    return null;
  }

  @override
  Future<NotificationListResult> getNotifications(
    String role, {
    bool forceRefresh = false,
  }) async {
    listCalls += 1;
    lastListedRole = role;
    lastForceRefresh = forceRefresh;
    if (queuedResults.isNotEmpty) {
      final int index = listCalls <= queuedResults.length
          ? listCalls - 1
          : queuedResults.length - 1;
      nextResult = queuedResults[index];
    }

    return nextResult;
  }

  @override
  Future<AppNotification> markAsRead(String role, int notificationId) async {
    markedIds.add(notificationId);
    final AppNotification current = nextResult.notifications.firstWhere(
      (AppNotification notification) => notification.id == notificationId,
    );

    nextResult = NotificationListResult(
      notifications: nextResult.notifications.map((
        AppNotification notification,
      ) {
        if (notification.id != notificationId) {
          return notification;
        }

        return notification.copyWith(isRead: true);
      }).toList(),
      unreadCount: nextResult.notifications.where((
        AppNotification notification,
      ) {
        return !notification.isRead && notification.id != notificationId;
      }).length,
    );

    return current.copyWith(isRead: true);
  }

  @override
  Future<int> markAllAsRead(String role) async {
    markAllCalls += 1;
    final int updatedCount = nextResult.notifications.where((
      AppNotification notification,
    ) {
      return !notification.isRead;
    }).length;

    nextResult = NotificationListResult(
      notifications: nextResult.notifications.map((
        AppNotification notification,
      ) {
        return notification.copyWith(isRead: true);
      }).toList(),
      unreadCount: 0,
    );

    return updatedCount;
  }
}

class _FakeAppointmentService extends Fake implements AppointmentService {
  int? lastFetchedAppointmentId;
  int availabilityCalls = 0;

  @override
  Future<Map<String, dynamic>> getPatientAppointment(int id) async {
    lastFetchedAppointmentId = id;

    return <String, dynamic>{
      'id': id,
      'appointment_date': '2026-05-10',
      'appointment_time': '10:00',
      'notes': '',
      'status': 'Reschedule Required',
    };
  }

  @override
  Future<Map<String, dynamic>> getAvailabilitySlots(
    String date, {
    int? ignoreAppointmentId,
  }) async {
    availabilityCalls += 1;

    return <String, dynamic>{
      'slots': <Map<String, dynamic>>[
        <String, dynamic>{
          'time': '10:00',
          'time_label': '10:00 AM',
          'status': 'available',
        },
        <String, dynamic>{
          'time': '10:30',
          'time_label': '10:30 AM',
          'status': 'available',
        },
      ],
      'unavailable_ranges': <Map<String, dynamic>>[],
    };
  }
}

void main() {
  testWidgets('loads live notifications and marks a tapped item as read', (
    WidgetTester tester,
  ) async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.writeUserInfo(<String, dynamic>{'role': 'patient'});

    final _FakeNotificationService notificationService =
        _FakeNotificationService()
          ..nextResult = NotificationListResult(
            notifications: <AppNotification>[
              AppNotification(
                id: 1,
                title: 'Appointment booked',
                message: 'Your appointment is pending approval.',
                createdAt: DateTime(2026, 3, 30, 9, 0),
                isRead: false,
                type: 'appointment_created',
                relatedAppointmentId: 77,
              ),
              AppNotification(
                id: 2,
                title: 'Reminder',
                message: 'You have an appointment tomorrow.',
                createdAt: DateTime(2026, 3, 29, 9, 0),
                isRead: true,
                type: 'reminder',
                relatedAppointmentId: 78,
              ),
            ],
            unreadCount: 1,
          );
    final _FakeAppointmentService appointmentService =
        _FakeAppointmentService();

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsView(
          notificationService: notificationService,
          appointmentService: appointmentService,
          tokenStorage: tokenStorage,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(notificationService.lastListedRole, 'patient');
    expect(find.text('Appointment booked'), findsOneWidget);
    expect(find.text('Your appointment is pending approval.'), findsOneWidget);
    expect(
      find.byKey(const Key('notification-mark-all-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('notification-tile-1')));
    await tester.pumpAndSettle();

    expect(notificationService.markedIds, <int>[1]);
    expect(find.byKey(const Key('notification-mark-all-button')), findsNothing);
  });

  testWidgets('mark all as read updates the notification actions', (
    WidgetTester tester,
  ) async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.writeUserInfo(<String, dynamic>{'role': 'staff'});

    final _FakeNotificationService notificationService =
        _FakeNotificationService()
          ..nextResult = NotificationListResult(
            notifications: <AppNotification>[
              AppNotification(
                id: 10,
                title: 'Queue update',
                message: 'A patient just checked in.',
                createdAt: DateTime(2026, 3, 30, 8, 30),
                isRead: false,
                type: 'queue',
              ),
              AppNotification(
                id: 11,
                title: 'Follow-up booking',
                message: 'A follow-up appointment was created.',
                createdAt: DateTime(2026, 3, 30, 8, 0),
                isRead: false,
                type: 'appointment_created',
              ),
            ],
            unreadCount: 2,
          );
    final _FakeAppointmentService appointmentService =
        _FakeAppointmentService();

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsView(
          notificationService: notificationService,
          appointmentService: appointmentService,
          tokenStorage: tokenStorage,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(notificationService.lastListedRole, 'staff');
    expect(find.text('Queue update'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-mark-all-button')));
    await tester.pumpAndSettle();

    expect(notificationService.markAllCalls, 1);
    expect(find.byKey(const Key('notification-mark-all-button')), findsNothing);
  });

  testWidgets('pull to refresh reloads the notifications list', (
    WidgetTester tester,
  ) async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    await tokenStorage.writeUserInfo(<String, dynamic>{'role': 'patient'});

    final _FakeNotificationService notificationService =
        _FakeNotificationService()
          ..queuedResults = <NotificationListResult>[
            NotificationListResult(
              notifications: <AppNotification>[
                AppNotification(
                  id: 30,
                  title: 'Queued update',
                  message: 'Initial notification state.',
                  createdAt: DateTime(2026, 3, 30, 8, 0),
                  isRead: false,
                  type: 'queue',
                ),
              ],
              unreadCount: 1,
            ),
            NotificationListResult(
              notifications: <AppNotification>[
                AppNotification(
                  id: 30,
                  title: 'Queued update',
                  message: 'Initial notification state.',
                  createdAt: DateTime(2026, 3, 30, 8, 0),
                  isRead: false,
                  type: 'queue',
                ),
                AppNotification(
                  id: 31,
                  title: 'Reminder',
                  message: 'Refreshed notification state.',
                  createdAt: DateTime(2026, 3, 30, 8, 30),
                  isRead: false,
                  type: 'reminder',
                ),
              ],
              unreadCount: 2,
            ),
          ];
    final _FakeAppointmentService appointmentService =
        _FakeAppointmentService();

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsView(
          notificationService: notificationService,
          appointmentService: appointmentService,
          tokenStorage: tokenStorage,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(notificationService.listCalls, 1);
    expect(find.byKey(const Key('notifications-refresh')), findsOneWidget);
    expect(find.text('Initial notification state.'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('notifications-list')),
      const Offset(0, 300),
    );
    await tester.pump();

    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(notificationService.listCalls, 2);
    expect(notificationService.lastForceRefresh, isTrue);
    expect(find.text('Refreshed notification state.'), findsOneWidget);
  });

  testWidgets(
    'renders the reusable empty state when there are no notifications',
    (WidgetTester tester) async {
      final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
      await tokenStorage.writeUserInfo(<String, dynamic>{'role': 'patient'});

      final _FakeNotificationService notificationService =
          _FakeNotificationService()
            ..nextResult = const NotificationListResult(
              notifications: <AppNotification>[],
              unreadCount: 0,
            );
      final _FakeAppointmentService appointmentService =
          _FakeAppointmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsView(
            notificationService: notificationService,
            appointmentService: appointmentService,
            tokenStorage: tokenStorage,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notifications-empty-state')),
        findsOneWidget,
      );
      expect(find.text('No notifications right now'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(notificationService.listCalls, 2);
      expect(notificationService.lastForceRefresh, isTrue);
    },
  );

  testWidgets(
    'reschedule notifications show a Reschedule Now button and open the reschedule page',
    (WidgetTester tester) async {
      final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
      await tokenStorage.writeUserInfo(<String, dynamic>{'role': 'patient'});

      final _FakeNotificationService notificationService =
          _FakeNotificationService()
            ..nextResult = NotificationListResult(
              notifications: <AppNotification>[
                AppNotification(
                  id: 50,
                  title: 'Appointment Needs Reschedule',
                  message: 'Your current appointment needs a new time.',
                  createdAt: DateTime(2026, 4, 25, 9, 0),
                  isRead: false,
                  type: 'appointment_reschedule_required',
                  relatedAppointmentId: 55,
                  actionType: 'reschedule',
                  actionLabel: 'Reschedule',
                ),
              ],
              unreadCount: 1,
            );
      final _FakeAppointmentService appointmentService =
          _FakeAppointmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsView(
            notificationService: notificationService,
            appointmentService: appointmentService,
            tokenStorage: tokenStorage,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Your current appointment needs a new time.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notification-action-button-50')),
        findsOneWidget,
      );
      expect(find.text('Reschedule Now'), findsOneWidget);

      await tester.tap(find.byKey(const Key('notification-action-button-50')));
      await tester.pumpAndSettle();

      expect(notificationService.markedIds, <int>[50]);
      expect(appointmentService.lastFetchedAppointmentId, 55);
      expect(appointmentService.availabilityCalls, 1);
      expect(
        find.byKey(const Key('reschedule-appointment-page')),
        findsOneWidget,
      );
      expect(find.text('Reschedule Appointment'), findsOneWidget);
    },
  );
}
