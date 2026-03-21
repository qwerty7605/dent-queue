import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/patient_record_service.dart';
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
  late PatientRecordService patientRecordService;
  late FakeBaseService fakeBaseService;

  setUp(() {
    fakeBaseService = FakeBaseService();
    patientRecordService = PatientRecordService(fakeBaseService);
  });

  test('getAllPatients should properly map response list', () async {
    fakeBaseService.nextResponse = {
      'data': [
        {
          'id': 1,
          'full_name': 'Test Patient',
          'contact_number': '09123456789'
        }
      ]
    };

    final patients = await patientRecordService.getAllPatients();

    expect(patients.length, 1);
    expect(patients[0]['full_name'], 'Test Patient');
    expect(fakeBaseService.lastPath, contains('patients'));
  });

  test('searchPatients should encode query and return results', () async {
    fakeBaseService.nextResponse = {
      'data': [
        {
          'id': 2,
          'full_name': 'Queried Patient'
        }
      ]
    };

    final patients = await patientRecordService.searchPatients('Queried');

    expect(patients.length, 1);
    expect(patients[0]['full_name'], 'Queried Patient');
    expect(fakeBaseService.lastPath, contains('search'));
    expect(fakeBaseService.lastPath, contains('Queried'));
  });
}
