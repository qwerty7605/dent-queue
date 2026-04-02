import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/patient_record_service.dart';
import 'package:frontend/services/base_service.dart';

class FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;
  int getJsonCallCount = 0;
  int deleteJsonCallCount = 0;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    getJsonCallCount += 1;
    lastPath = path;
    return mapper(nextResponse);
  }

  @override
  Future<T> deleteJson<T>(String path, T Function(dynamic json) mapper) async {
    deleteJsonCallCount += 1;
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
    patientRecordService.invalidatePatientCaches();
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

  test('getAllPatients uses cache until invalidated', () async {
    fakeBaseService.nextResponse = {
      'data': [
        {'id': 1, 'full_name': 'Cached Patient'}
      ]
    };

    final first = await patientRecordService.getAllPatients();
    final second = await patientRecordService.getAllPatients();

    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(fakeBaseService.getJsonCallCount, 1);

    patientRecordService.invalidatePatientCaches();
    await patientRecordService.getAllPatients();

    expect(fakeBaseService.getJsonCallCount, 2);
  });

  test('deactivatePatient invalidates cached patient reads', () async {
    fakeBaseService.nextResponse = {
      'data': [
        {'id': 3, 'full_name': 'Before Remove'}
      ]
    };
    await patientRecordService.getAllPatients();
    expect(fakeBaseService.getJsonCallCount, 1);

    fakeBaseService.nextResponse = {
      'message': 'Patient removed.'
    };
    await patientRecordService.deactivatePatient('3');
    expect(fakeBaseService.deleteJsonCallCount, 1);

    fakeBaseService.nextResponse = {
      'data': []
    };
    await patientRecordService.getAllPatients();

    expect(fakeBaseService.getJsonCallCount, 2);
  });
}
