import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
  late AppointmentService appointmentService;
  late FakeBaseService fakeBaseService;

  setUp(() {
    fakeBaseService = FakeBaseService();
    appointmentService = AppointmentService(fakeBaseService);
    appointmentService.invalidateAppointmentCaches();
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
