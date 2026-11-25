import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/business_error.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../monthly_reports/data/monthly_report_pdf_filename.dart';
import '../../domain/entities/supervision_report.dart';
import '../models/supervision_report_model.dart';

abstract class SupervisionReportsRemoteDataSource {
  /// GET /reports/compliance (limit=1, no year/month): the months of the
  /// active year.
  Future<SupervisionReportPeriods> getPeriods({CancelToken? cancelToken});

  /// GET /reports/compliance for one month.
  Future<SupervisionCompliancePage> getCompliance({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    CancelToken? cancelToken,
  });

  /// GET /monthly-reports/admin/list for one month.
  Future<SupervisionReportPage> getReports({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    CancelToken? cancelToken,
  });

  /// GET /monthly-reports/:reportId/pdf; returns the local file path.
  Future<String> downloadReportPdf(
    String reportId, {
    CancelToken? cancelToken,
  });
}

class SupervisionReportsRemoteDataSourceImpl
    implements SupervisionReportsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionReportsDS';

  SupervisionReportsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String get _compliance => '$_baseUrl/reports/compliance';
  String get _reports => '$_baseUrl${ApiEndpoints.monthlyReports}';

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      if (isAuthorizationStale(e)) throw authorizationStaleException(e);
      // Only `code` and `message` are read; never `details`.
      throw businessErrorFrom(e);
    }
    if (e is AppException) throw e;
    throw ServerException(message: e.toString());
  }

  bool _isOk(int? code) => code == 200 || code == 201;

  Object? _unwrap(Object? raw) =>
      raw is Map && raw.containsKey('data') ? raw['data'] : raw;

  Never _badResponse(Response<dynamic> response) => throw ServerException(
        message: 'Unexpected response (${response.statusCode})',
        code: response.statusCode,
      );

  @override
  Future<SupervisionReportPeriods> getPeriods({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        _compliance,
        queryParameters: {'limit': 1},
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionReportModel.parsePeriods(_unwrap(response.data));
    } catch (e) {
      AppLogger.e('Error en getPeriods (supervision reports)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionCompliancePage> getCompliance({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        _compliance,
        queryParameters: {
          'year': period.year,
          'month': period.month,
          'page': page,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionReportModel.parseCompliancePage(
        _unwrap(response.data),
        limit: limit,
      );
    } catch (e) {
      AppLogger.e('Error en getCompliance (supervision reports)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionReportPage> getReports({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_reports/admin/list',
        queryParameters: {
          'year': period.year,
          'month': period.month,
          'page': page,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionReportModel.parseReportPage(
        _unwrap(response.data),
        limit: limit,
      );
    } catch (e) {
      AppLogger.e('Error en getReports (supervision reports)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<String> downloadReportPdf(
    String reportId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final fallback = 'informe-mensual-$reportId.pdf';
      final dir = await getTemporaryDirectory();
      late final String filePath;

      // The authenticated Dio client attaches the Bearer token in the header,
      // so the JWT never ends up in the URL.
      await _dio.download(
        '$_reports/${Uri.encodeComponent(reportId)}/pdf',
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
          message: 'The report PDF is empty',
          errorCode: 'REPORT_PDF_EMPTY',
        );
      }
      return filePath;
    } catch (e) {
      AppLogger.e('Error en downloadReportPdf (supervision reports)',
          tag: _tag, error: e);
      if (e is DioException &&
          e.type != DioExceptionType.cancel &&
          !isAuthorizationStale(e)) {
        final body = await _decodeErrorBody(e.response?.data);
        if (body != null) {
          throw businessErrorFromResponse(
            e.response?.statusCode,
            body,
            fallbackMessage: e.message,
          );
        }
      }
      _rethrow(e);
    }
  }

  /// A download error body may be a decoded map, raw bytes or a stream.
  Future<Map<String, dynamic>?> _decodeErrorBody(Object? data) async {
    try {
      Object? value = data;
      if (value is ResponseBody) {
        final bytes = <int>[];
        await for (final chunk in value.stream) {
          bytes.addAll(chunk);
        }
        value = bytes;
      }
      if (value is List<int>) value = utf8.decode(value);
      if (value is String) value = jsonDecode(value);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }
}
