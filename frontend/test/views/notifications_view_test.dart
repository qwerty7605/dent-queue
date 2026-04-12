import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/models/app_notification.dart';
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

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsView(
          notificationService: notificationService,
          tokenStorage: tokenStorage,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(notificationService.lastListedRole, 'patient');
    expect(find.text('1 unread notification'), findsOneWidget);
    expect(
      find.byKey(const Key('notification-mark-all-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('notification-unread-dot-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-tile-1')));
    await tester.pumpAndSettle();

    expect(notificationService.markedIds, <int>[1]);
    expect(find.text('All caught up'), findsOneWidget);
    expect(find.byKey(const Key('notification-mark-all-button')), findsNothing);
    expect(find.byKey(const Key('notification-unread-dot-1')), findsNothing);
  });

  testWidgets('mark all as read updates the unread summary', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsView(
          notificationService: notificationService,
          tokenStorage: tokenStorage,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(notificationService.lastListedRole, 'staff');
    expect(find.text('2 unread notifications'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-mark-all-button')));
    await tester.pumpAndSettle();

    expect(notificationService.markAllCalls, 1);
    expect(find.text('All caught up'), findsOneWidget);
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

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsView(
          notificationService: notificationService,
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

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsView(
            notificationService: notificationService,
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
}
