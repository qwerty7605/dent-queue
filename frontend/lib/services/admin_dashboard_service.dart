import 'dart:typed_data';

import '../core/endpoints.dart';
import '../core/short_term_cache.dart';
import 'base_service.dart';

enum ReportExportFormat {
  csv('csv', 'CSV', 'text/csv'),
  excel('excel', 'Excel', 'application/vnd.ms-excel'),
  pdf('pdf', 'PDF', 'application/pdf');

  const ReportExportFormat(this.queryValue, this.label, this.acceptHeader);

  final String queryValue;
  final String label;
  final String acceptHeader;
}

class ReportExportFile {
  const ReportExportFile({
    required this.filename,
    required this.bytes,
    required this.contentType,
    this.wasLimited = false,
    this.exportedRecordCount,
    this.totalRecordCount,
  });

  final String filename;
  final Uint8List bytes;
  final String contentType;
  final bool wasLimited;
  final int? exportedRecordCount;
  final int? totalRecordCount;
}

class AdminDashboardService {
  AdminDashboardService(this._baseService);

  static const Duration _dashboardCacheTtl = Duration(seconds: 60);
  static const Duration _reportCacheTtl = Duration(minutes: 2);
  static const String _dashboardStatsCache = 'dashboard-stats';
  static const String _reportSummaryCache = 'report-summary';
  static const String _reportTrendsCache = 'report-trends';

  final BaseService _baseService;

  Map<String, int>? getCachedStats({bool allowStale = false}) {
    final ShortTermCacheHit<dynamic>? cachedStats =
        ShortTermCache.readEntry<dynamic>(
          _dashboardStatsCache,
          'all',
          allowStale: allowStale,
        );

    if (cachedStats?.value is Map) {
      return Map<String, int>.from(cachedStats!.value as Map);
    }

    return null;
  }

  Future<Map<String, int>> getStats({bool forceRefresh = false}) async {
    final dynamic cachedStats = ShortTermCache.read<dynamic>(
      _dashboardStatsCache,
      'all',
    );
    if (!forceRefresh && cachedStats is Map) {
      return Map<String, int>.from(cachedStats);
    }

    return ShortTermCache.runSingleFlight(
      _dashboardStatsCache,
      'all',
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminDashboardStats(
            forceRefresh
                ? const <String, String>{'force_refresh': 'true'}
                : const <String, String>{},
          ),
          (data) => data,
        );

        if (response is Map && response.containsKey('data')) {
          final dataMap = response['data'];
          if (dataMap is Map) {
            final data = Map<String, dynamic>.from(dataMap);
            final result = <String, int>{
              'patients_count': data['patients_count'] as int? ?? 0,
              'staff_count': data['staff_count'] as int? ?? 0,
              'intern_count': data['intern_count'] as int? ?? 0,
              'staff_accounts_count': data['staff_accounts_count'] as int? ?? 0,
              'appointments_count': data['appointments_count'] as int? ?? 0,
            };
            ShortTermCache.write(
              _dashboardStatsCache,
              'all',
              result,
              ttl: _dashboardCacheTtl,
            );
            return result;
          }
        }

        final result = <String, int>{
          'patients_count': 0,
          'staff_count': 0,
          'intern_count': 0,
          'staff_accounts_count': 0,
          'appointments_count': 0,
        };
        ShortTermCache.write(
          _dashboardStatsCache,
          'all',
          result,
          ttl: _dashboardCacheTtl,
        );
        return result;
      },
    );
  }

  Future<Map<String, int>> getReportSummary([
    Map<String, String> filters = const <String, String>{},
    bool forceRefresh = false,
  ]) async {
    final String cacheKey = _filterCacheKey(filters);
    final dynamic cachedSummary = ShortTermCache.read<dynamic>(
      _reportSummaryCache,
      cacheKey,
    );
    if (!forceRefresh && cachedSummary is Map) {
      return Map<String, int>.from(cachedSummary);
    }

    return ShortTermCache.runSingleFlight(
      _reportSummaryCache,
      cacheKey,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminReportsSummary(
            _forceRefreshFilters(filters, forceRefresh),
          ),
          (data) => data,
        );

        if (response is Map && response.containsKey('data')) {
          final dataMap = response['data'];
          if (dataMap is Map) {
            final data = Map<String, dynamic>.from(dataMap);
            final result = <String, int>{
              'total': data['total_appointments'] as int? ?? 0,
              'report_records': data['total_report_records'] as int? ?? 0,
              'pending': data['pending_count'] as int? ?? 0,
              'approved': data['approved_count'] as int? ?? 0,
              'completed': data['completed_count'] as int? ?? 0,
              'cancelled': data['cancelled_count'] as int? ?? 0,
              'cancelled_by_doctor':
                  data['cancelled_by_doctor_count'] as int? ?? 0,
              'reschedule_required':
                  data['reschedule_required_count'] as int? ?? 0,
            };
            ShortTermCache.write(
              _reportSummaryCache,
              cacheKey,
              result,
              ttl: _reportCacheTtl,
            );
            return result;
          }
        }

        final result = <String, int>{
          'total': 0,
          'report_records': 0,
          'pending': 0,
          'approved': 0,
          'completed': 0,
          'cancelled': 0,
          'cancelled_by_doctor': 0,
          'reschedule_required': 0,
        };
        ShortTermCache.write(
          _reportSummaryCache,
          cacheKey,
          result,
          ttl: _reportCacheTtl,
        );
        return result;
      },
    );
  }

  Map<String, int>? getCachedReportSummary([
    Map<String, String> filters = const <String, String>{},
    bool allowStale = false,
  ]) {
    final String cacheKey = _filterCacheKey(filters);
    final ShortTermCacheHit<dynamic>? cachedSummary =
        ShortTermCache.readEntry<dynamic>(
          _reportSummaryCache,
          cacheKey,
          allowStale: allowStale,
        );

    if (cachedSummary?.value is Map) {
      return Map<String, int>.from(cachedSummary!.value as Map);
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> getAppointmentTrends(
    String trendType, [
    Map<String, String> filters = const <String, String>{},
    bool forceRefresh = false,
  ]) async {
    final String cacheKey = '$trendType|${_filterCacheKey(filters)}';
    final dynamic cachedTrends = ShortTermCache.read<dynamic>(
      _reportTrendsCache,
      cacheKey,
    );
    if (!forceRefresh && cachedTrends is List) {
      return cachedTrends
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return ShortTermCache.runSingleFlight(
      _reportTrendsCache,
      cacheKey,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminReportsTrends(
            trendType,
            _forceRefreshFilters(filters, forceRefresh),
          ),
          (data) => data,
        );

        if (response is Map<String, dynamic> &&
            response['data'] is List<dynamic>) {
          final result = (response['data'] as List<dynamic>)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          ShortTermCache.write(
            _reportTrendsCache,
            cacheKey,
            result,
            ttl: _reportCacheTtl,
          );
          return result;
        }

        const result = <Map<String, dynamic>>[];
        ShortTermCache.write(
          _reportTrendsCache,
          cacheKey,
          result,
          ttl: _reportCacheTtl,
        );
        return result;
      },
    );
  }

  Future<ReportExportFile> exportDetailedRecords([
    ReportExportFormat format = ReportExportFormat.csv,
    Map<String, String> filters = const <String, String>{},
    bool forceRefresh = false,
  ]) async {
    final Map<String, String> exportFilters = <String, String>{
      ...filters,
      'format': format.queryValue,
      if (forceRefresh) 'force_refresh': 'true',
    };
    final response = await _baseService.getRaw(
      Endpoints.adminReportsExport(exportFilters),
      headers: <String, String>{'Accept': format.acceptHeader},
      timeout: Duration(minutes: format == ReportExportFormat.pdf ? 2 : 3),
    );

    return ReportExportFile(
      filename: _extractFilename(response.headers['content-disposition']),
      bytes: response.bodyBytes,
      contentType: response.headers['content-type'] ?? format.acceptHeader,
      wasLimited: response.headers['x-export-limited']?.toLowerCase() == 'true',
      exportedRecordCount: _parseHeaderInt(
        response.headers['x-export-record-count'],
      ),
      totalRecordCount: _parseHeaderInt(
        response.headers['x-export-total-count'],
      ),
    );
  }

  Map<String, String> _forceRefreshFilters(
    Map<String, String> filters,
    bool forceRefresh,
  ) {
    if (!forceRefresh) {
      return filters;
    }

    return <String, String>{...filters, 'force_refresh': 'true'};
  }

  String _extractFilename(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.isEmpty) {
      return 'report-records.csv';
    }

    final encodedMatch = RegExp(
      r'''filename\*=UTF-8''([^;]+)''',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    if (encodedMatch != null) {
      return Uri.decodeComponent(encodedMatch.group(1)!).replaceAll('"', '');
    }

    final filenameMatch = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    if (filenameMatch != null) {
      return filenameMatch.group(1)!.trim();
    }

    return 'report-records.csv';
  }

  int? _parseHeaderInt(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return int.tryParse(value.trim());
  }

  void invalidateDashboardStatsCache() {
    ShortTermCache.invalidateNamespace(_dashboardStatsCache);
  }

  void invalidateReportCaches() {
    invalidateDashboardStatsCache();
    ShortTermCache.invalidateNamespace(_reportSummaryCache);
    ShortTermCache.invalidateNamespace(_reportTrendsCache);
  }

  static void invalidateSharedDashboardStatsCache() {
    ShortTermCache.invalidateNamespace(_dashboardStatsCache);
  }

  static void invalidateSharedReportCaches() {
    ShortTermCache.invalidateNamespace(_reportSummaryCache);
    ShortTermCache.invalidateNamespace(_reportTrendsCache);
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
}
