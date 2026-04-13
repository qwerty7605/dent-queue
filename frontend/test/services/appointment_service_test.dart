import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/short_term_cache.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/services/base_service.dart';

class FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;
  Object? lastBody;
  int getJsonCallCount = 0;
  int postJsonCallCount = 0;
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
  Future<T> postJson<T>(
    String path,
    Object? body,
    T Function(dynamic json) mapper,
  ) async {
    postJsonCallCount += 1;
    lastPath = path;
    lastBody = body;
    return mapper(nextResponse);
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

void main() {
  const Duration cacheTtl = Duration(minutes: 1);
  const String servicesCache = 'appointment-services';
  const String adminMasterListCache = 'appointment-admin-master-list';
  const String adminMasterListPageCache = 'appointment-admin-master-list-page';
  const String patientAppointmentsCache = 'appointment-patient-list';
  const String medicalHistoryCache = 'appointment-medical-history';
  const String recycleBinCache = 'appointment-recycle-bin';
  const String adminCalendarAppointmentsCache = 'appointment-admin-calendar';
  const String adminTodayQueueCache = 'appointment-admin-today-queue';
  const String dashboardStatsCache = 'dashboard-stats';
  const String reportSummaryCache = 'report-summary';

  late AppointmentService appointmentService;
  late FakeBaseService fakeBaseService;

  setUp(() {
    fakeBaseService = FakeBaseService();
    appointmentService = AppointmentService(fakeBaseService);
    ShortTermCache.clear();
  });

  test(
    'getAdminMasterList should return list of appointments from data key',
    () async {
      fakeBaseService.nextResponse = {
        'data': [
          {
            'patient_name': 'John Doe',
            'service': 'Dental Checkup',
            'status': 'Approved',
            'date': '2026-04-01',
          },
        ],
      };

      final result = await appointmentService.getAdminMasterList(
        <String, String>{
          'status': 'Approved',
          'booking_type': 'Online Booking',
        },
      );

      expect(result.length, 1);
      expect(result[0]['patient_name'], 'John Doe');
      expect(result[0]['status'], 'Approved');
      expect(
        fakeBaseService.lastPath,
        '/api/v1/admin/appointments/master-list?status=Approved&booking_type=Online+Booking',
      );
    },
  );

  test('getAdminMasterList uses cache until invalidated', () async {
    fakeBaseService.nextResponse = {
      'data': [
        {
          'patient_name': 'Jane Doe',
          'service': 'Cleaning',
          'status': 'Pending',
          'date': '2026-04-02',
        },
      ],
    };

    final first = await appointmentService.getAdminMasterList(<String, String>{
      'status': 'Pending',
    });
    final second = await appointmentService.getAdminMasterList(<String, String>{
      'status': 'Pending',
    });

    expect(first, second);
    expect(fakeBaseService.getJsonCallCount, 1);

    appointmentService.invalidateAppointmentCaches();
    await appointmentService.getAdminMasterList(<String, String>{
      'status': 'Pending',
    });

    expect(fakeBaseService.getJsonCallCount, 2);
  });

  test(
    'getAdminMasterListPage should request page params and map metadata',
    () async {
      fakeBaseService.nextResponse = {
        'data': [
          {
            'patient_name': 'John Doe',
            'service': 'Dental Checkup',
            'status': 'Approved',
            'date': '2026-04-01',
          },
        ],
        'meta': {
          'current_page': 2,
          'per_page': 10,
          'total': 26,
          'has_more_pages': true,
        },
      };

      final page = await appointmentService.getAdminMasterListPage(
        filters: <String, String>{'status': 'Approved'},
        page: 2,
        perPage: 10,
      );

      expect(page.items, hasLength(1));
      expect(page.items.first['patient_name'], 'John Doe');
      expect(page.currentPage, 2);
      expect(page.perPage, 10);
      expect(page.totalItems, 26);
      expect(page.hasMorePages, isTrue);
      expect(
        fakeBaseService.lastPath,
        '/api/v1/admin/appointments/master-list?status=Approved&page=2&per_page=10',
      );
    },
  );

  test('cancelAppointment invalidates cached appointment lists', () async {
    fakeBaseService.nextResponse = {
      'data': [
        {
          'patient_name': 'John Doe',
          'service': 'Dental Checkup',
          'status': 'Approved',
          'date': '2026-04-01',
        },
      ],
    };

    await appointmentService.getAdminMasterList();
    expect(fakeBaseService.getJsonCallCount, 1);

    fakeBaseService.nextResponse = {'message': 'Cancelled'};
    await appointmentService.cancelAppointment(12);
    expect(fakeBaseService.patchJsonCallCount, 1);

    fakeBaseService.nextResponse = {
      'data': [
        {
          'patient_name': 'John Doe',
          'service': 'Dental Checkup',
          'status': 'Cancelled',
          'date': '2026-04-01',
        },
      ],
    };
    await appointmentService.getAdminMasterList();

    expect(fakeBaseService.getJsonCallCount, 2);
  });

  test(
    'createAppointment clears appointment, queue, dashboard, and report caches without clearing services',
    () async {
      ShortTermCache.write(
        adminMasterListCache,
        'all',
        const <Map<String, dynamic>>[
          <String, dynamic>{'id': 1},
        ],
        ttl: cacheTtl,
      );
      ShortTermCache.write(
        adminMasterListPageCache,
        'page=1&per_page=25',
        const <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1},
          ],
          'meta': <String, dynamic>{
            'current_page': 1,
            'per_page': 25,
            'total': 30,
            'has_more_pages': true,
          },
        },
        ttl: cacheTtl,
      );
      ShortTermCache.write(
        adminTodayQueueCache,
        'today',
        const <String, dynamic>{
          'queue_summary': <String, dynamic>{'total': 1},
        },
        ttl: cacheTtl,
      );
      ShortTermCache.write(dashboardStatsCache, 'all', const <String, int>{
        'appointments_count': 3,
      }, ttl: cacheTtl);
      ShortTermCache.write(reportSummaryCache, 'all', const <String, int>{
        'total': 3,
      }, ttl: cacheTtl);
      ShortTermCache.write(servicesCache, 'all', const <Map<String, dynamic>>[
        <String, dynamic>{'id': 6, 'name': 'Cleaning'},
      ], ttl: cacheTtl);

      fakeBaseService.nextResponse = <String, dynamic>{'message': 'Created'};

      await appointmentService.createAppointment(<String, dynamic>{
        'service_id': 6,
        'appointment_date': '2026-04-13',
        'time_slot': '09:00',
      });

      expect(ShortTermCache.read<dynamic>(adminMasterListCache, 'all'), isNull);
      expect(
        ShortTermCache.read<dynamic>(
          adminMasterListPageCache,
          'page=1&per_page=25',
        ),
        isNull,
      );
      expect(
        ShortTermCache.read<dynamic>(adminTodayQueueCache, 'today'),
        isNull,
      );
      expect(ShortTermCache.read<dynamic>(dashboardStatsCache, 'all'), isNull);
      expect(ShortTermCache.read<dynamic>(reportSummaryCache, 'all'), isNull);
      expect(ShortTermCache.read<dynamic>(servicesCache, 'all'), isNotNull);
    },
  );

  test(
    'updateAdminAppointmentStatus invalidates completed appointment reads and leaves services cached',
    () async {
      ShortTermCache.write(
        patientAppointmentsCache,
        'current-user',
        const <Map<String, dynamic>>[
          <String, dynamic>{'id': 7, 'status': 'Pending'},
        ],
        ttl: cacheTtl,
      );
      ShortTermCache.write(
        medicalHistoryCache,
        'current-user',
        const <Map<String, dynamic>>[
          <String, dynamic>{'id': 2, 'status': 'Completed'},
        ],
        ttl: cacheTtl,
      );
      ShortTermCache.write(
        adminCalendarAppointmentsCache,
        '2026-04-13',
        const <Map<String, dynamic>>[
          <String, dynamic>{'id': 7},
        ],
        ttl: cacheTtl,
      );
      ShortTermCache.write(reportSummaryCache, 'all', const <String, int>{
        'completed': 1,
      }, ttl: cacheTtl);
      ShortTermCache.write(servicesCache, 'all', const <Map<String, dynamic>>[
        <String, dynamic>{'id': 4, 'name': 'Whitening'},
      ], ttl: cacheTtl);

      fakeBaseService.nextResponse = <String, dynamic>{'message': 'Updated'};

      await appointmentService.updateAdminAppointmentStatus(7, 'completed');

      expect(
        ShortTermCache.read<dynamic>(patientAppointmentsCache, 'current-user'),
        isNull,
      );
      expect(
        ShortTermCache.read<dynamic>(medicalHistoryCache, 'current-user'),
        isNull,
      );
      expect(
        ShortTermCache.read<dynamic>(
          adminCalendarAppointmentsCache,
          '2026-04-13',
        ),
        isNull,
      );
      expect(ShortTermCache.read<dynamic>(reportSummaryCache, 'all'), isNull);
      expect(ShortTermCache.read<dynamic>(servicesCache, 'all'), isNotNull);
    },
  );

  test(
    'cancelAppointment clears recycle-bin-related caches without clearing services',
    () async {
      ShortTermCache.write(
        patientAppointmentsCache,
        'current-user',
        const <Map<String, dynamic>>[
          <String, dynamic>{'id': 12, 'status': 'Approved'},
        ],
        ttl: cacheTtl,
      );
      ShortTermCache.write(
        recycleBinCache,
        'patient',
        const <Map<String, dynamic>>[
          <String, dynamic>{'id': 13, 'status': 'Cancelled'},
        ],
        ttl: cacheTtl,
      );
      ShortTermCache.write(
        adminTodayQueueCache,
        'today',
        const <String, dynamic>{
          'queue_summary': <String, dynamic>{'total': 1},
        },
        ttl: cacheTtl,
      );
      ShortTermCache.write(reportSummaryCache, 'all', const <String, int>{
        'cancelled': 0,
      }, ttl: cacheTtl);
      ShortTermCache.write(servicesCache, 'all', const <Map<String, dynamic>>[
        <String, dynamic>{'id': 2, 'name': 'Root Canal'},
      ], ttl: cacheTtl);

      fakeBaseService.nextResponse = <String, dynamic>{'message': 'Cancelled'};

      await appointmentService.cancelAppointment(12);

      expect(
        ShortTermCache.read<dynamic>(patientAppointmentsCache, 'current-user'),
        isNull,
      );
      expect(ShortTermCache.read<dynamic>(recycleBinCache, 'patient'), isNull);
      expect(
        ShortTermCache.read<dynamic>(adminTodayQueueCache, 'today'),
        isNull,
      );
      expect(ShortTermCache.read<dynamic>(reportSummaryCache, 'all'), isNull);
      expect(ShortTermCache.read<dynamic>(servicesCache, 'all'), isNotNull);
    },
  );

  test('callNextQueue should send selected date when provided', () async {
    fakeBaseService.nextResponse = {
      'message': 'Next patient called successfully.',
      'called_queue': {'queue_number': 2},
    };

    final result = await appointmentService.callNextQueue(date: '2026-03-23');

    expect(result['called_queue']['queue_number'], 2);
    expect(fakeBaseService.lastPath, contains('queues/call-next'));
    expect(fakeBaseService.lastBody, {'date': '2026-03-23'});
  });

  test('getAdminMasterList collapses concurrent matching requests', () async {
    fakeBaseService.pendingGetJsonResponse = Completer<dynamic>();

    final Future<List<Map<String, dynamic>>> first = appointmentService
        .getAdminMasterList(<String, String>{'status': 'Approved'});
    final Future<List<Map<String, dynamic>>> second = appointmentService
        .getAdminMasterList(<String, String>{'status': 'Approved'});

    expect(fakeBaseService.getJsonCallCount, 1);

    fakeBaseService.pendingGetJsonResponse!.complete(<String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'patient_name': 'Taylor Cruz',
          'service': 'Cleaning',
          'status': 'Approved',
          'date': '2026-04-04',
        },
      ],
    });

    final List<List<Map<String, dynamic>>> results =
        await Future.wait<List<Map<String, dynamic>>>(
          <Future<List<Map<String, dynamic>>>>[first, second],
        );

    expect(results[0], hasLength(1));
    expect(results[1], hasLength(1));
    expect(results[0].first['patient_name'], 'Taylor Cruz');
    expect(results[1].first['patient_name'], 'Taylor Cruz');
  });
}
