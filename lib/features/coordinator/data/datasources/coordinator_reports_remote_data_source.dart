import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../monthly_reports/data/monthly_report_pdf_filename.dart';
import '../../domain/entities/coordinator_report.dart';
import '../../domain/entities/report_compliance.dart';
import '../models/coordinator_reports_models.dart';

/// Page size of the admin report lists (backend cap: 100).
const int kCoordinatorReportsPageSize = 100;

/// Safety stop for the list pagination loop.
const int _kMaxPages = 10;

/// Compliance page size (backend cap: 200 clubs).
const int _kComplianceLimit = 200;

const String _compliance = '/reports/compliance';

/// Read-only monthly report endpoints a coordinator can call (reports:read +
/// reports:download, scoped by the backend to coordinator_assignments).
abstract class CoordinatorReportsRemoteDataSource {
  /// GET /reports/compliance
  Future<ReportCompliance> getCompliance({
    int? year,
    int? month,
    CancelToken? cancelToken,
  });

  /// GET /monthly-reports/admin/list, every page.
  Future<List<CoordinatorReport>> listReports({
    int? year,
    int? period,
    CancelToken? cancelToken,
  });

  /// Downloads the report PDF to a temp file and returns its path.
  Future<String> downloadReportPdf({
    required int reportId,
    CancelToken? cancelToken,
  });
}

class CoordinatorReportsRemoteDataSourceImpl
    implements CoordinatorReportsRemoteDataSource {
  CoordinatorReportsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'CoordinatorReportsDS';

  @override
  Future<ReportCompliance> getCompliance({
    int? year,
    int? month,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_compliance',
        queryParameters: {
          'limit': _kComplianceLimit,
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
        cancelToken: cancelToken,
      );
      if (_isOk(response.statusCode)) {
        return ReportComplianceModel.fromJson(_unwrap(response.data));
      }
      throw ServerException(
        message: tr('coordinator.reports.errors.fetch_compliance'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getCompliance', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<CoordinatorReport>> listReports({
    int? year,
    int? period,
    CancelToken? cancelToken,
  }) async {
    try {
      final path = '${ApiEndpoints.monthlyReports}/admin/list';
      final filters = <String, dynamic>{
        if (year != null) 'year': year,
        if (period != null) 'month': period,
      };

      final reports = <CoordinatorReport>[];
      for (var page = 1; page <= _kMaxPages; page++) {
        final response = await _dio.get(
          '$_baseUrl$path',
          queryParameters: {
            ...filters,
            'page': page,
            'limit': kCoordinatorReportsPageSize,
          },
          cancelToken: cancelToken,
        );
        if (!_isOk(response.statusCode)) {
          throw ServerException(
            message: tr('coordinator.reports.errors.fetch_list'),
            code: response.statusCode,
          );
        }
        final result = CoordinatorReportPage.fromJson(_unwrap(response.data));
        reports.addAll(result.items);
        if (result.items.length < kCoordinatorReportsPageSize ||
            reports.length >= result.total) {
          break;
        }
      }
      return reports;
    } catch (e) {
      AppLogger.e('Error en listReports', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<String> downloadReportPdf({
    required int reportId,
    CancelToken? cancelToken,
  }) async {
    try {
      final path = '${ApiEndpoints.monthlyReports}/$reportId/pdf';
      final fallback = 'informe-mensual-$reportId.pdf';
      final dir = await getTemporaryDirectory();
      late final String filePath;

      // The authenticated Dio client attaches the Bearer token in the header,
      // so the JWT never ends up in the URL.
      await _dio.download(
        '$_baseUrl$path',
        (headers) {
          final filename = monthlyReportPdfFileName(
            headers.value('content-disposition'),
            fallback: fallback,
          );
          filePath = '${dir.path}/$filename';
          return filePath;
        },
        cancelToken: cancelToken,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final file = File(filePath);
      if (!await file.exists() || await file.length() == 0) {
        throw ServerException(
          message: tr('coordinator.reports.errors.pdf_empty'),
        );
      }
      return filePath;
    } catch (e) {
      AppLogger.e('Error en downloadReportPdf', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  bool _isOk(int? code) => code == 200 || code == 201 || code == 204;

  /// `{ status, data: {...} }` → `data`.
  Map<String, dynamic> _unwrap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      return data is Map<String, dynamic> ? data : raw;
    }
    return const <String, dynamic>{};
  }

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      // Rechazo local por autorización obsoleta: conserva mensaje y código.
      if (isAuthorizationStale(e)) throw authorizationStaleException(e);
      final code = e.response?.statusCode;
      if (code == 403) {
        throw AuthException(
          message: tr('coordinator.reports.errors.forbidden'),
          code: code,
        );
      }
      if (code == 404) {
        throw ServerException(
          message: tr('coordinator.reports.errors.not_found'),
          code: code,
        );
      }
      final data = e.response?.data;
      final msg = data is Map && data['message'] != null
          ? data['message'].toString()
          : (e.message ?? tr('common.error_network'));
      throw ServerException(message: msg, code: code);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }
}
