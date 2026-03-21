import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/profile_service.dart';
import 'package:frontend/services/base_service.dart';

class FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;
  Map<String, String>? lastFields;

  @override
  Future<T> postMultipartJson<T>(
    String path, {
    required Map<String, String> fields,
    Map<String, File>? files,
    required T Function(dynamic json) mapper,
  }) async {
    lastPath = path;
    lastFields = fields;
    return mapper(nextResponse);
  }
}

void main() {
  late ProfileService profileService;
  late FakeBaseService fakeBaseService;

  setUp(() {
    fakeBaseService = FakeBaseService();
    profileService = ProfileService(fakeBaseService);
  });

  test('updateProfile ensures multipart request uses PUT override', () async {
    fakeBaseService.nextResponse = {
      'message': 'Profile updated successfully',
      'user': {'id': 1}
    };

    final fields = {'first_name': 'Aldritch'};
    
    final response = await profileService.updateProfile(1, fields: fields, role: 'patient');

    expect(response['message'], 'Profile updated successfully');
    expect(fakeBaseService.lastPath, contains('patient/profile/1'));
    expect(fakeBaseService.lastFields?['_method'], 'PUT');
    expect(fakeBaseService.lastFields?['first_name'], 'Aldritch');
  });

  test('updateProfile resolves correct endpoint for staff', () async {
    fakeBaseService.nextResponse = {};
    
    await profileService.updateProfile(2, fields: {}, role: 'staff');
    expect(fakeBaseService.lastPath, contains('staff/profile/2'));
  });
}
