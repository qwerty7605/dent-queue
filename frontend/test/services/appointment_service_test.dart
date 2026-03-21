import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/services/base_service.dart';

class FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    lastPath = path;
    return mapper(nextResponse);
  }
}

void main() {
  late AppointmentService appointmentService;
  late FakeBaseService fakeBaseService;

  setUp(() {
    fakeBaseService = FakeBaseService();
    appointmentService = AppointmentService(fakeBaseService);
  });

  test('getAdminMasterList should return list of appointments from data key', () async {
    fakeBaseService.nextResponse = {
      'data': [
        {
          'patient_name': 'John Doe',
          'service': 'Dental Checkup',
          'status': 'Approved',
          'date': '2026-04-01'
        }
      ]
    };

    final result = await appointmentService.getAdminMasterList();

    expect(result.length, 1);
    expect(result[0]['patient_name'], 'John Doe');
    expect(result[0]['status'], 'Approved');
    expect(fakeBaseService.lastPath, contains('master-list'));
  });
}
