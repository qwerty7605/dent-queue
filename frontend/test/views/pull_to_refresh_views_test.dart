import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/short_term_cache.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/views/patient_dashboard_view.dart';
import 'package:frontend/views/staff_dashboard_view.dart';

class _FakeAppointmentService extends Fake implements AppointmentService {
  List<List<Map<String, dynamic>>> patientAppointmentsResults =
      <List<Map<String, dynamic>>>[];
  List<Map<String, dynamic>> patientQueueResults = <Map<String, dynamic>>[];
  List<List<Map<String, dynamic>>> adminMasterListResults =
      <List<Map<String, dynamic>>>[];
  List<List<Map<String, dynamic>>> adminAppointmentsResults =
      <List<Map<String, dynamic>>>[];
  List<Map<String, dynamic>> adminQueueResults = <Map<String, dynamic>>[];
  List<List<Map<String, dynamic>>> recycleBinResults =
      <List<Map<String, dynamic>>>[];

  int patientAppointmentsCalls = 0;
  int patientQueueCalls = 0;
  int adminMasterListCalls = 0;
  int adminAppointmentsCalls = 0;
  int adminQueueCalls = 0;
  int recycleBinCalls = 0;

  @override
  void invalidateAppointmentCaches() {}

  @override
  void invalidatePatientTodayQueueCache() {}

  @override
  Future<List<Map<String, dynamic>>> getPatientAppointments() async {
    patientAppointmentsCalls += 1;
    return _resultAt(patientAppointmentsResults, patientAppointmentsCalls);
  }

  @override
  Future<Map<String, dynamic>> getPatientTodayQueue({
    bool forceRefresh = false,
  }) async {
    patientQueueCalls += 1;
    return _mapResultAt(patientQueueResults, patientQueueCalls);
  }

  @override
  Future<List<Map<String, dynamic>>> getAdminMasterList([
    Map<String, String> filters = const <String, String>{},
  ]) async {
    adminMasterListCalls += 1;
    return _resultAt(adminMasterListResults, adminMasterListCalls);
  }

  @override
  Future<List<Map<String, dynamic>>> getAdminAppointmentsByDate(
    String date,
  ) async {
    adminAppointmentsCalls += 1;
    return _resultAt(adminAppointmentsResults, adminAppointmentsCalls);
  }

  @override
  Future<Map<String, dynamic>> getAdminTodayQueue([
    String? date,
    bool forceRefresh = false,
  ]) async {
    adminQueueCalls += 1;
    return _mapResultAt(adminQueueResults, adminQueueCalls);
  }

  @override
  Future<List<Map<String, dynamic>>> getRecycleBinAppointments(
    bool isStaff,
  ) async {
    recycleBinCalls += 1;
    return _resultAt(recycleBinResults, recycleBinCalls);
  }

  List<Map<String, dynamic>> _resultAt(
    List<List<Map<String, dynamic>>> source,
    int callNumber,
  ) {
    if (source.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final int index = callNumber <= source.length
        ? callNumber - 1
        : source.length - 1;

    return source[index]
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _mapResultAt(
    List<Map<String, dynamic>> source,
    int callNumber,
  ) {
    if (source.isEmpty) {
      return <String, dynamic>{};
    }

    final int index = callNumber <= source.length
        ? callNumber - 1
        : source.length - 1;

    return Map<String, dynamic>.from(source[index]);
  }
}

class _FakeNotificationService extends Fake implements NotificationService {
  int getNotificationsCalls = 0;

  @override
  Future<NotificationListResult> getNotifications(
    String role, {
    bool forceRefresh = false,
  }) async {
    getNotificationsCalls += 1;
    return const NotificationListResult(
      notifications: <AppNotification>[],
      unreadCount: 0,
    );
  }
}

void main() {
  setUp(() {
    ShortTermCache.clear();
  });

  String todayString() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> triggerRefresh(
    WidgetTester tester,
    Finder refreshIndicator,
  ) async {
    final RefreshIndicator indicator = tester.widget<RefreshIndicator>(
      refreshIndicator,
    );
    await indicator.onRefresh();
    await tester.pump();
  }

  testWidgets(
    'patient dashboard pull to refresh reloads appointments and queue',
    (WidgetTester tester) async {
      final String today = todayString();
      final _FakeAppointmentService appointmentService =
          _FakeAppointmentService()
            ..patientAppointmentsResults = <List<Map<String, dynamic>>>[
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1,
                  'service_type': 'Dental Check-up',
                  'appointment_date': today,
                  'appointment_time': '09:00',
                  'status': 'Pending',
                  'queue_number': '01',
                  'notes': '',
                },
              ],
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 2,
                  'service_type': 'Root Canal',
                  'appointment_date': today,
                  'appointment_time': '10:00',
                  'status': 'Approved',
                  'queue_number': '02',
                  'notes': '',
                },
              ],
            ]
            ..patientQueueResults = <Map<String, dynamic>>[
              <String, dynamic>{
                'now_serving': <String, dynamic>{
                  'queue_number': 1,
                  'patient_name': 'Alex Stone',
                },
                'patient_queue': <String, dynamic>{
                  'queue_number': 4,
                  'people_ahead': 3,
                  'status': 'Approved',
                  'is_now_serving': false,
                },
              },
              <String, dynamic>{
                'now_serving': <String, dynamic>{
                  'queue_number': 2,
                  'patient_name': 'Mia Lee',
                },
                'patient_queue': <String, dynamic>{
                  'queue_number': 5,
                  'people_ahead': 2,
                  'status': 'Approved',
                  'is_now_serving': false,
                },
              },
            ];

      await tester.pumpWidget(
        MaterialApp(
          home: PatientDashboardView(
            userInfo: const <String, dynamic>{},
            onLogout: () {},
            loggingOut: false,
            appointmentService: appointmentService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('patient-dashboard-refresh')),
        findsOneWidget,
      );
      expect(appointmentService.patientAppointmentsCalls, 1);
      expect(appointmentService.patientQueueCalls, 1);
      expect(find.text('3 patients ahead of you.'), findsOneWidget);

      await triggerRefresh(
        tester,
        find.byKey(const Key('patient-dashboard-refresh')),
      );

      await tester.pumpAndSettle();

      expect(appointmentService.patientAppointmentsCalls, 2);
      expect(appointmentService.patientQueueCalls, 2);
      expect(find.text('2 patients ahead of you.'), findsOneWidget);
    },
  );

  testWidgets(
    'staff dashboard pull to refresh reloads appointments and queue',
    (WidgetTester tester) async {
      final String today = todayString();
      final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
      final _FakeNotificationService notificationService =
          _FakeNotificationService();
      final _FakeAppointmentService appointmentService =
          _FakeAppointmentService()
            ..adminMasterListResults = <List<Map<String, dynamic>>>[
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'appointment_id': 11,
                  'patient_name': 'Ava Lopez',
                  'service': 'Teeth Cleaning',
                  'date': today,
                  'contact': '09123456789',
                  'status': 'Approved',
                  'booking_type': 'Online',
                  'queue_number': '01',
                },
              ],
            ]
            ..adminAppointmentsResults = <List<Map<String, dynamic>>>[
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 11,
                  'patient_name': 'Ava Lopez',
                  'service_type': 'Teeth Cleaning',
                  'appointment_date': today,
                  'time': '09:00',
                  'status': 'Approved',
                  'queue_number': 1,
                  'is_called': false,
                },
              ],
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 12,
                  'patient_name': 'Noah Cruz',
                  'service_type': 'Tooth Extraction',
                  'appointment_date': today,
                  'time': '10:00',
                  'status': 'Approved',
                  'queue_number': 2,
                  'is_called': false,
                },
              ],
            ]
            ..adminQueueResults = <Map<String, dynamic>>[
              <String, dynamic>{
                'now_serving': <String, dynamic>{
                  'queue_number': 1,
                  'patient_name': 'Ava Lopez',
                },
                'next_up': <String, dynamic>{
                  'queue_number': 2,
                  'patient_name': 'Noah Cruz',
                },
              },
              <String, dynamic>{
                'now_serving': <String, dynamic>{
                  'queue_number': 2,
                  'patient_name': 'Noah Cruz',
                },
                'next_up': <String, dynamic>{
                  'queue_number': 3,
                  'patient_name': 'Lia Santos',
                },
              },
            ];

      await tester.pumpWidget(
        MaterialApp(
          home: StaffDashboardView(
            userInfo: const <String, dynamic>{},
            tokenStorage: tokenStorage,
            onLogout: () {},
            loggingOut: false,
            appointmentService: appointmentService,
            notificationService: notificationService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-dashboard-refresh')), findsOneWidget);
      expect(appointmentService.adminMasterListCalls, 0);
      expect(appointmentService.adminAppointmentsCalls, 1);
      expect(appointmentService.adminQueueCalls, 1);
      expect(appointmentService.recycleBinCalls, 1);
      expect(notificationService.getNotificationsCalls, 1);
      expect(find.text('Ava Lopez'), findsWidgets);

      await triggerRefresh(
        tester,
        find.byKey(const Key('staff-dashboard-refresh')),
      );

      await tester.pumpAndSettle();

      expect(appointmentService.adminMasterListCalls, 0);
      expect(appointmentService.adminAppointmentsCalls, 2);
      expect(appointmentService.adminQueueCalls, 2);
      expect(appointmentService.recycleBinCalls, 2);
      expect(notificationService.getNotificationsCalls, 1);
      expect(find.text('Noah Cruz'), findsWidgets);
    },
  );

  testWidgets(
    'intern dashboard hides restricted controls and skips blocked calls',
    (WidgetTester tester) async {
      final String today = todayString();
      final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
      final _FakeAppointmentService appointmentService =
          _FakeAppointmentService()
            ..adminMasterListResults = <List<Map<String, dynamic>>>[
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'appointment_id': 21,
                  'patient_name': 'Mia Flores',
                  'service': 'Teeth Cleaning',
                  'date': today,
                  'status': 'Pending',
                  'queue_number': '01',
                },
              ],
            ]
            ..adminAppointmentsResults = <List<Map<String, dynamic>>>[
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 21,
                  'patient_name': 'Mia Flores',
                  'service_type': 'Teeth Cleaning',
                  'appointment_date': today,
                  'time': '09:00',
                  'status': 'Pending',
                  'queue_number': 1,
                },
              ],
            ]
            ..adminQueueResults = <Map<String, dynamic>>[
              <String, dynamic>{
                'now_serving': <String, dynamic>{
                  'queue_number': 1,
                  'patient_name': 'Mia Flores',
                },
                'next_up': <String, dynamic>{
                  'queue_number': 2,
                  'patient_name': 'Lia Santos',
                },
              },
            ]
            ..recycleBinResults = <List<Map<String, dynamic>>>[
              <Map<String, dynamic>>[
                <String, dynamic>{'id': 99, 'patient_name': 'Blocked Item'},
              ],
            ];
      final _FakeNotificationService notificationService =
          _FakeNotificationService();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffDashboardView(
            userInfo: const <String, dynamic>{},
            tokenStorage: tokenStorage,
            onLogout: () {},
            loggingOut: false,
            readOnly: true,
            appointmentService: appointmentService,
            notificationService: notificationService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(appointmentService.adminMasterListCalls, 0);
      expect(appointmentService.adminAppointmentsCalls, 1);
      expect(appointmentService.adminQueueCalls, 1);
      expect(appointmentService.recycleBinCalls, 0);
      expect(notificationService.getNotificationsCalls, 0);

      expect(find.text('Call Next'), findsNothing);
      expect(find.byIcon(Icons.notifications_none), findsNothing);
      expect(find.text('Walk In'), findsNothing);
      expect(find.text('Records'), findsNothing);

      await tester.ensureVisible(find.text('Teeth Cleaning'));
      await tester.tap(find.text('Teeth Cleaning'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Cancel'), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Profile'));
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsNothing);
      expect(
        find.text('Profile details are view-only for intern accounts.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Walk-in'), findsNothing);
      expect(find.text('Records'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Recycle Bin'), findsNothing);
    },
  );

  testWidgets(
    'patient dashboard auto refresh updates queue without reloading the full appointment list',
    (WidgetTester tester) async {
      final String today = todayString();
      final _FakeAppointmentService appointmentService =
          _FakeAppointmentService()
            ..patientAppointmentsResults = <List<Map<String, dynamic>>>[
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1,
                  'service_type': 'Dental Check-up',
                  'appointment_date': today,
                  'appointment_time': '09:00',
                  'status': 'Pending',
                  'queue_number': '01',
                  'notes': '',
                },
              ],
            ]
            ..patientQueueResults = <Map<String, dynamic>>[
              <String, dynamic>{
                'now_serving': <String, dynamic>{
                  'queue_number': 1,
                  'patient_name': 'Alex Stone',
                },
                'patient_queue': <String, dynamic>{
                  'queue_number': 4,
                  'people_ahead': 3,
                  'status': 'Approved',
                  'is_now_serving': false,
                },
              },
              <String, dynamic>{
                'now_serving': <String, dynamic>{
                  'queue_number': 2,
                  'patient_name': 'Mia Lee',
                },
                'patient_queue': <String, dynamic>{
                  'queue_number': 4,
                  'people_ahead': 2,
                  'status': 'Approved',
                  'is_now_serving': false,
                },
              },
            ];

      await tester.pumpWidget(
        MaterialApp(
          home: PatientDashboardView(
            userInfo: const <String, dynamic>{},
            onLogout: () {},
            loggingOut: false,
            appointmentService: appointmentService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(appointmentService.patientAppointmentsCalls, 1);
      expect(appointmentService.patientQueueCalls, 1);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(appointmentService.patientAppointmentsCalls, 1);
      expect(appointmentService.patientQueueCalls, 2);
    },
  );
}
