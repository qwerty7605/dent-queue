import '../core/endpoints.dart';
import '../models/status_response.dart';
import 'base_service.dart';

class StatusService {
  StatusService(this._baseService);

  final BaseService _baseService;

  Future<StatusResponse> getStatus() async {
    return _baseService.getJson(
      Endpoints.status,
      (json) => StatusResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}
