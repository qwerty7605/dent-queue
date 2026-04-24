import '../core/endpoints.dart';
import '../core/paginated_result.dart';
import '../core/short_term_cache.dart';
import 'admin_dashboard_service.dart';
import 'base_service.dart';

class AppointmentService {
  AppointmentService(this._baseService);

  static const Duration _cacheTtl = Duration(seconds: 30);
  static const String _adminMasterListCache = 'appointment-admin-master-list';
  static const String _adminMasterListPageCache =
      'appointment-admin-master-list-page';
  static const String _patientAppointmentsCache = 'appointment-patient-list';
  static const String _medicalHistoryCache = 'appointment-medical-history';
  static const String _recycleBinCache = 'appointment-recycle-bin';
  static const String _adminAppointmentsByDateCache =
      'appointment-admin-by-date';
  static const String _adminCalendarAppointmentsCache =
      'appointment-admin-calendar';
  static const String _calendarAppointmentDetailsCache =
      'appointment-calendar-detail';
  static const String _patientTodayQueueCache =
      'appointment-patient-today-queue';
  static const String _adminTodayQueueCache = 'appointment-admin-today-queue';
  static const String _servicesCache = 'appointment-services';
  static const String _availabilitySlotsCache = 'appointment-availability';

  final BaseService _baseService;

  Future<List<Map<String, dynamic>>> getServices() async {
    final dynamic cached = ShortTermCache.read<dynamic>(_servicesCache, 'all');
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return ShortTermCache.runSingleFlight(_servicesCache, 'all', () async {
      final response = await _baseService.getJson<dynamic>(
        Endpoints.services,
        (data) => data,
      );
      if (response is Map<String, dynamic> &&
          response.containsKey('services')) {
        final servicesList = response['services'] as List<dynamic>;
        final result = servicesList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        ShortTermCache.write(_servicesCache, 'all', result, ttl: _cacheTtl);
        return result;
      }
      const result = <Map<String, dynamic>>[];
      ShortTermCache.write(_servicesCache, 'all', result, ttl: _cacheTtl);
      return result;
    });
  }

  Future<Map<String, dynamic>> createAppointment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.appointments,
      payload,
      (data) => data,
    );
    _invalidateAfterAppointmentCreated();
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAdminAppointment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.adminAppointments,
      payload,
      (data) => data,
    );
    _invalidateAfterAppointmentCreated();
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAvailabilitySlots(
    String date, {
    int? ignoreAppointmentId,
  }) async {
    final String cacheKey = ignoreAppointmentId == null
        ? date
        : '$date::$ignoreAppointmentId';
    final dynamic cached = ShortTermCache.read<dynamic>(
      _availabilitySlotsCache,
      cacheKey,
    );
    if (cached is Map) {
      return Map<String, dynamic>.from(cached);
    }

    return ShortTermCache.runSingleFlight(
      _availabilitySlotsCache,
      cacheKey,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.availabilitySlots(
            date,
            ignoreAppointmentId: ignoreAppointmentId,
          ),
          (data) => data,
        );

        if (response is Map<String, dynamic> && response['data'] is Map) {
          final result = Map<String, dynamic>.from(response['data'] as Map);
          ShortTermCache.write(
            _availabilitySlotsCache,
            cacheKey,
            result,
            ttl: _cacheTtl,
          );
          return result;
        }

        const result = <String, dynamic>{};
        ShortTermCache.write(
          _availabilitySlotsCache,
          cacheKey,
          result,
          ttl: _cacheTtl,
        );
        return result;
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAdminMasterList([
    Map<String, String> filters = const <String, String>{},
  ]) async {
    final String cacheKey = _filterCacheKey(filters);
    final dynamic cachedMasterList = ShortTermCache.read<dynamic>(
      _adminMasterListCache,
      cacheKey,
    );
    if (cachedMasterList is List) {
      return cachedMasterList
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return ShortTermCache.runSingleFlight(
      _adminMasterListCache,
      cacheKey,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminMasterList(filters),
          (data) => data,
        );

        if (response is Map<String, dynamic> && response.containsKey('data')) {
          final appointmentsList = response['data'] as List<dynamic>;
          final result = appointmentsList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          ShortTermCache.write(
            _adminMasterListCache,
            cacheKey,
            result,
            ttl: _cacheTtl,
          );
          return result;
        }

        const result = <Map<String, dynamic>>[];
        ShortTermCache.write(
          _adminMasterListCache,
          cacheKey,
          result,
          ttl: _cacheTtl,
        );
        return result;
      },
    );
  }

  Future<PaginatedResult<Map<String, dynamic>>> getAdminMasterListPage({
    Map<String, String> filters = const <String, String>{},
    int page = 1,
    int perPage = 25,
  }) async {
    final String cacheKey = _pagedFilterCacheKey(
      filters,
      page: page,
      perPage: perPage,
    );
    final dynamic cachedMasterListPage = ShortTermCache.read<dynamic>(
      _adminMasterListPageCache,
      cacheKey,
    );
    if (cachedMasterListPage is Map<String, dynamic>) {
      return PaginatedResult<Map<String, dynamic>>.fromResponse(
        cachedMasterListPage,
        (dynamic item) => Map<String, dynamic>.from(item as Map),
        fallbackPage: page,
        fallbackPerPage: perPage,
      );
    }

    return ShortTermCache.runSingleFlight(
      _adminMasterListPageCache,
      cacheKey,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminMasterList(<String, String>{
            ...filters,
            'page': page.toString(),
            'per_page': perPage.toString(),
          }),
          (data) => data,
        );

        if (response is Map<String, dynamic>) {
          ShortTermCache.write(
            _adminMasterListPageCache,
            cacheKey,
            response,
            ttl: _cacheTtl,
          );
          return PaginatedResult<Map<String, dynamic>>.fromResponse(
            response,
            (dynamic item) => Map<String, dynamic>.from(item as Map),
            fallbackPage: page,
            fallbackPerPage: perPage,
          );
        }

        const Map<String, dynamic> emptyResponse = <String, dynamic>{
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
        };
        ShortTermCache.write(
          _adminMasterListPageCache,
          cacheKey,
          emptyResponse,
          ttl: _cacheTtl,
        );
        return const PaginatedResult<Map<String, dynamic>>(
          items: <Map<String, dynamic>>[],
          currentPage: 1,
          perPage: 25,
          totalItems: 0,
          hasMorePages: false,
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> getPatientAppointments() async {
    const String cacheKey = 'current-user';
    final dynamic cachedPatientList = ShortTermCache.read<dynamic>(
      _patientAppointmentsCache,
      cacheKey,
    );
    if (cachedPatientList is List) {
      return cachedPatientList
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return ShortTermCache.runSingleFlight(
      _patientAppointmentsCache,
      cacheKey,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.appointments,
          (data) => data,
        );
        if (response is Map<String, dynamic> &&
            response.containsKey('appointments')) {
          final appointmentsList = response['appointments'] as List<dynamic>;
          final result = appointmentsList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          ShortTermCache.write(
            _patientAppointmentsCache,
            cacheKey,
            result,
            ttl: _cacheTtl,
          );
          return result;
        }

        const result = <Map<String, dynamic>>[];
        ShortTermCache.write(
          _patientAppointmentsCache,
          cacheKey,
          result,
          ttl: _cacheTtl,
        );
        return result;
      },
    );
  }

  Future<Map<String, dynamic>> getPatientAppointment(int id) async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.patientAppointment(id),
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['appointment'] is Map) {
      return Map<String, dynamic>.from(response['appointment'] as Map);
    }

    throw StateError('Appointment details response is missing appointment data.');
  }

  Future<List<Map<String, dynamic>>> getMedicalHistory() async {
    final dynamic cached = ShortTermCache.read<dynamic>(
      _medicalHistoryCache,
      'current-user',
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return ShortTermCache.runSingleFlight(
      _medicalHistoryCache,
      'current-user',
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.medicalHistory,
          (data) => data,
        );
        if (response is Map<String, dynamic> &&
            response.containsKey('appointments')) {
          final appointmentsList = response['appointments'] as List<dynamic>;
          final result = appointmentsList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          ShortTermCache.write(
            _medicalHistoryCache,
            'current-user',
            result,
            ttl: _cacheTtl,
          );
          return result;
        }

        const result = <Map<String, dynamic>>[];
        ShortTermCache.write(
          _medicalHistoryCache,
          'current-user',
          result,
          ttl: _cacheTtl,
        );
        return result;
      },
    );
  }

  Future<Map<String, dynamic>> cancelAppointment(int id) async {
    final response = await _baseService.patchJson<dynamic>(
      Endpoints.cancelAppointment(id),
      {},
      (data) => data,
    );
    _invalidateAfterAppointmentCancelled();
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rescheduleAppointment(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.putJson<dynamic>(
      Endpoints.rescheduleAppointment(id),
      payload,
      (data) => data,
    );
    _invalidateAfterAppointmentCreated();
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> restoreAppointment(int id) async {
    final response = await _baseService.patchJson<dynamic>(
      Endpoints.restoreAppointment(id),
      {},
      (data) => data,
    );
    _invalidateAfterAppointmentRestored();
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getRecycleBinAppointments(
    bool isStaff,
  ) async {
    final String cacheKey = isStaff ? 'staff' : 'patient';
    final dynamic cached = ShortTermCache.read<dynamic>(
      _recycleBinCache,
      cacheKey,
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return ShortTermCache.runSingleFlight(_recycleBinCache, cacheKey, () async {
      final endpoint = isStaff
          ? Endpoints.staffRecycleBin
          : Endpoints.patientRecycleBin;
      final response = await _baseService.getJson<dynamic>(
        endpoint,
        (data) => data,
      );
      if (response is Map<String, dynamic> &&
          response.containsKey('recycle_bin')) {
        final binList = response['recycle_bin'] as List<dynamic>;
        final result = binList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        ShortTermCache.write(
          _recycleBinCache,
          cacheKey,
          result,
          ttl: _cacheTtl,
        );
        return result;
      }

      const result = <Map<String, dynamic>>[];
      ShortTermCache.write(_recycleBinCache, cacheKey, result, ttl: _cacheTtl);
      return result;
    });
  }

  Future<List<Map<String, dynamic>>> getAdminAppointmentsByDate(
    String date,
  ) async {
    final dynamic cachedAppointmentsByDate = ShortTermCache.read<dynamic>(
      _adminAppointmentsByDateCache,
      date,
    );
    if (cachedAppointmentsByDate is List) {
      return cachedAppointmentsByDate
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return ShortTermCache.runSingleFlight(
      _adminAppointmentsByDateCache,
      date,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminAppointmentsByDate(date),
          (data) => data,
        );

        if (response is Map<String, dynamic> &&
            response.containsKey('appointments')) {
          final appointmentsList = response['appointments'] as List<dynamic>;
          final result = appointmentsList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          ShortTermCache.write(
            _adminAppointmentsByDateCache,
            date,
            result,
            ttl: _cacheTtl,
          );
          return result;
        }

        const result = <Map<String, dynamic>>[];
        ShortTermCache.write(
          _adminAppointmentsByDateCache,
          date,
          result,
          ttl: _cacheTtl,
        );
        return result;
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAdminCalendarAppointments(
    String date,
  ) async {
    final dynamic cachedCalendarAppointments = ShortTermCache.read<dynamic>(
      _adminCalendarAppointmentsCache,
      date,
    );
    if (cachedCalendarAppointments is List) {
      return cachedCalendarAppointments
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return ShortTermCache.runSingleFlight(
      _adminCalendarAppointmentsCache,
      date,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminCalendarAppointments(date),
          (data) => data,
        );

        if (response is Map<String, dynamic> &&
            response.containsKey('appointments')) {
          final appointmentsList = response['appointments'] as List<dynamic>;
          final result = appointmentsList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          ShortTermCache.write(
            _adminCalendarAppointmentsCache,
            date,
            result,
            ttl: _cacheTtl,
          );
          return result;
        }

        const result = <Map<String, dynamic>>[];
        ShortTermCache.write(
          _adminCalendarAppointmentsCache,
          date,
          result,
          ttl: _cacheTtl,
        );
        return result;
      },
    );
  }

  Future<Map<String, dynamic>> getAdminCalendarAppointmentDetails(
    int id,
  ) async {
    final dynamic cached = ShortTermCache.read<dynamic>(
      _calendarAppointmentDetailsCache,
      id.toString(),
    );
    if (cached is Map) {
      return Map<String, dynamic>.from(cached);
    }

    return ShortTermCache.runSingleFlight(
      _calendarAppointmentDetailsCache,
      id.toString(),
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminCalendarAppointmentDetails(id),
          (data) => data,
        );

        if (response is Map<String, dynamic> &&
            response['appointment'] is Map) {
          final result = Map<String, dynamic>.from(
            response['appointment'] as Map,
          );
          ShortTermCache.write(
            _calendarAppointmentDetailsCache,
            id.toString(),
            result,
            ttl: _cacheTtl,
          );
          return result;
        }

        const result = <String, dynamic>{};
        ShortTermCache.write(
          _calendarAppointmentDetailsCache,
          id.toString(),
          result,
          ttl: _cacheTtl,
        );
        return result;
      },
    );
  }

  Future<Map<String, dynamic>> updateAdminAppointmentStatus(
    int id,
    String status,
  ) async {
    final response = await _baseService.patchJson<dynamic>(
      Endpoints.adminUpdateAppointmentStatus(id),
      {'status': status},
      (data) => data,
    );

    _invalidateAfterAppointmentUpdated(status);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createWalkInAppointment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.adminWalkInAppointment,
      payload,
      (data) => data,
    );
    _invalidateAfterAppointmentCreated();
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPatientTodayQueue({
    bool forceRefresh = false,
  }) async {
    final dynamic cached = ShortTermCache.read<dynamic>(
      _patientTodayQueueCache,
      'current-user',
    );
    if (!forceRefresh && cached is Map) {
      return Map<String, dynamic>.from(cached);
    }

    return ShortTermCache.runSingleFlight(
      _patientTodayQueueCache,
      'current-user',
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.patientTodayQueue(
            forceRefresh
                ? const <String, String>{'force_refresh': 'true'}
                : const <String, String>{},
          ),
          (data) => data,
        );
        final result = Map<String, dynamic>.from(response as Map);
        ShortTermCache.write(
          _patientTodayQueueCache,
          'current-user',
          result,
          ttl: _cacheTtl,
        );
        return result;
      },
    );
  }

  Future<Map<String, dynamic>> joinPatientTodayQueue() async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.patientJoinQueue,
      {},
      (data) => data,
    );
    _invalidateAfterQueueUpdated();
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAdminTodayQueue([
    String? date,
    bool forceRefresh = false,
  ]) async {
    final String cacheKey = date == null || date.isEmpty ? 'today' : date;
    final dynamic cached = ShortTermCache.read<dynamic>(
      _adminTodayQueueCache,
      cacheKey,
    );
    if (!forceRefresh && cached is Map) {
      return Map<String, dynamic>.from(cached);
    }

    return ShortTermCache.runSingleFlight(
      _adminTodayQueueCache,
      cacheKey,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminTodayQueue(
            date,
            queryParameters: forceRefresh
                ? const <String, String>{'force_refresh': 'true'}
                : const <String, String>{},
          ),
          (data) => data,
        );
        final result = Map<String, dynamic>.from(response as Map);
        ShortTermCache.write(
          _adminTodayQueueCache,
          cacheKey,
          result,
          ttl: _cacheTtl,
        );
        return result;
      },
    );
  }

  Future<Map<String, dynamic>> callNextQueue({String? date}) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.adminCallNextQueue,
      date == null || date.isEmpty ? {} : {'date': date},
      (data) => data,
    );
    _invalidateAfterQueueUpdated();
    return response as Map<String, dynamic>;
  }

  void invalidateAppointmentCaches() {
    ShortTermCache.invalidateNamespace(_servicesCache);
    ShortTermCache.invalidateNamespace(_adminMasterListCache);
    ShortTermCache.invalidateNamespace(_adminMasterListPageCache);
    ShortTermCache.invalidateNamespace(_patientAppointmentsCache);
    ShortTermCache.invalidateNamespace(_medicalHistoryCache);
    ShortTermCache.invalidateNamespace(_recycleBinCache);
    ShortTermCache.invalidateNamespace(_adminAppointmentsByDateCache);
    ShortTermCache.invalidateNamespace(_adminCalendarAppointmentsCache);
    ShortTermCache.invalidateNamespace(_calendarAppointmentDetailsCache);
    ShortTermCache.invalidateNamespace(_patientTodayQueueCache);
    ShortTermCache.invalidateNamespace(_adminTodayQueueCache);
    AdminDashboardService.invalidateSharedDashboardStatsCache();
    AdminDashboardService.invalidateSharedReportCaches();
  }

  void _invalidateAfterAppointmentCreated() {
    _invalidateCommonAppointmentMutationCaches();
  }

  void _invalidateAfterAppointmentUpdated(String status) {
    _invalidateCommonAppointmentMutationCaches();

    if (_isCompletedStatus(status)) {
      ShortTermCache.invalidateNamespace(_medicalHistoryCache);
    }

    if (_isCancelledStatus(status)) {
      ShortTermCache.invalidateNamespace(_recycleBinCache);
    }
  }

  void _invalidateAfterAppointmentCancelled() {
    _invalidateCommonAppointmentMutationCaches();
    ShortTermCache.invalidateNamespace(_recycleBinCache);
  }

  void _invalidateAfterAppointmentRestored() {
    _invalidateCommonAppointmentMutationCaches();
    ShortTermCache.invalidateNamespace(_recycleBinCache);
  }

  void _invalidateAfterQueueUpdated() {
    ShortTermCache.invalidateNamespace(_adminMasterListCache);
    ShortTermCache.invalidateNamespace(_adminMasterListPageCache);
    ShortTermCache.invalidateNamespace(_patientAppointmentsCache);
    ShortTermCache.invalidateNamespace(_adminAppointmentsByDateCache);
    ShortTermCache.invalidateNamespace(_adminCalendarAppointmentsCache);
    ShortTermCache.invalidateNamespace(_calendarAppointmentDetailsCache);
    ShortTermCache.invalidateNamespace(_patientTodayQueueCache);
    ShortTermCache.invalidateNamespace(_adminTodayQueueCache);
    ShortTermCache.invalidateNamespace(_availabilitySlotsCache);
  }

  void _invalidateCommonAppointmentMutationCaches() {
    ShortTermCache.invalidateNamespace(_adminMasterListCache);
    ShortTermCache.invalidateNamespace(_adminMasterListPageCache);
    ShortTermCache.invalidateNamespace(_patientAppointmentsCache);
    ShortTermCache.invalidateNamespace(_adminAppointmentsByDateCache);
    ShortTermCache.invalidateNamespace(_adminCalendarAppointmentsCache);
    ShortTermCache.invalidateNamespace(_calendarAppointmentDetailsCache);
    ShortTermCache.invalidateNamespace(_patientTodayQueueCache);
    ShortTermCache.invalidateNamespace(_adminTodayQueueCache);
    ShortTermCache.invalidateNamespace(_availabilitySlotsCache);
    AdminDashboardService.invalidateSharedDashboardStatsCache();
    AdminDashboardService.invalidateSharedReportCaches();
  }

  bool _isCompletedStatus(String status) {
    final String normalizedStatus = status.trim().toLowerCase();
    return normalizedStatus == 'completed';
  }

  bool _isCancelledStatus(String status) {
    final String normalizedStatus = status.trim().toLowerCase();
    return normalizedStatus == 'cancelled' || normalizedStatus == 'canceled';
  }

  void invalidatePatientTodayQueueCache() {
    ShortTermCache.invalidateNamespace(_patientTodayQueueCache);
  }

  void invalidateAdminTodayQueueCache([String? date]) {
    if (date == null || date.isEmpty) {
      ShortTermCache.invalidateNamespace(_adminTodayQueueCache);
      return;
    }

    ShortTermCache.invalidate(_adminTodayQueueCache, date);
  }

  String _filterCacheKey(Map<String, String> filters) {
    if (filters.isEmpty) {
      return 'all';
    }

    final List<MapEntry<String, String>> entries = filters.entries.toList()
      ..sort((MapEntry<String, String> a, MapEntry<String, String> b) {
        final int keyOrder = a.key.compareTo(b.key);
        if (keyOrder != 0) {
          return keyOrder;
        }

        return a.value.compareTo(b.value);
      });

    return entries
        .map((MapEntry<String, String> entry) {
          return '${entry.key}=${entry.value}';
        })
        .join('&');
  }

  String _pagedFilterCacheKey(
    Map<String, String> filters, {
    required int page,
    required int perPage,
  }) {
    return '${_filterCacheKey(filters)}::page=$page::per_page=$perPage';
  }
}
