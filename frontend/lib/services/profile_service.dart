import 'dart:io';

import '../core/endpoints.dart';
import '../services/base_service.dart';

class ProfileService {
  ProfileService(this._baseService);

  final BaseService _baseService;

  Future<Map<String, dynamic>> updateProfile(
    int userId, {
    required Map<String, String> fields,
    required String role,
    File? profilePicture,
  }) async {
    final Map<String, File> files = {};
    if (profilePicture != null) {
      files['profile_picture'] = profilePicture;
    }

    // Workaround since our backend supports PUT/PATCH but HTTP multipart is strictly POST
    // We add _method field to override the HTTP verb in Laravel.
    fields['_method'] = 'PUT';

    final json = await _baseService.postMultipartJson<dynamic>(
      _resolveUpdateEndpoint(userId, role),
      fields: fields,
      files: files.isNotEmpty ? files : null,
      mapper: (data) => data as Map<String, dynamic>,
    );

    return json;
  }

  String _resolveUpdateEndpoint(int userId, String role) {
    switch (role.trim().toLowerCase()) {
      case 'staff':
      case 'admin':
        return Endpoints.updateStaffProfile(userId);
      default:
        return Endpoints.updatePatientProfile(userId);
    }
  }
}
