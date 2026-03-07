import 'dart:io';

import '../core/endpoints.dart';
import '../services/base_service.dart';

class ProfileService {
  ProfileService(this._baseService);

  final BaseService _baseService;

  Future<Map<String, dynamic>> updateProfile(
    int userId, {
    required Map<String, String> fields,
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
      Endpoints.updateProfile(userId),
      fields: fields,
      files: files.isNotEmpty ? files : null,
      mapper: (data) => data as Map<String, dynamic>,
    );

    return json;
  }
}
