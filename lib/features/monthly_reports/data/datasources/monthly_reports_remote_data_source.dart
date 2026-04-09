import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/monthly_report_model.dart';

/// Interfaz para el data source remoto de informes mensuales
abstract class MonthlyReportsRemoteDataSource {
  Future<MonthlyReportPreviewModel> getPreview(
    int enrollmentId, {
    required int month,
    required int year,
    CancelToken? cancelToken,
  });

  Future<List<MonthlyReportModel>> getReportsByEnrollment(int enrollmentId, {CancelToken? cancelToken});

  Future<MonthlyReportModel> getReportDetail(int reportId, {CancelToken? cancelToken});

  /// Descarga el PDF del informe usando el cliente autenticado y devuelve
  /// la ruta local del archivo temporal.
  Future<String> downloadReportPdf(int reportId, {CancelToken? cancelToken});
}

/// Implementación del data source remoto de informes mensuales
class MonthlyReportsRemoteDataSourceImpl
    implements MonthlyReportsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'MonthlyReportsDS';

  MonthlyReportsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      final msg = _extractDioMessage(e);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is List) return msg.join(', ');
        return (msg ?? e.message ?? 'Error de conexion').toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? 'Error de conexion';
  }

  Map<String, dynamic> _unwrapData(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
        return raw['data'] as Map<String, dynamic>;
      }
      return raw;
    }
    return {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic raw) {
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ── GET /api/v1/monthly-reports/preview/:enrollmentId ───────────────────

  @override
  Future<MonthlyReportPreviewModel> getPreview(
    int enrollmentId, {
    required int month,
    required int year,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.monthlyReports}/preview/$enrollmentId',
        queryParameters: {'month': month, 'year': year},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return MonthlyReportPreviewModel.fromJson(
            _unwrapData(response.data));
      }

      throw ServerException(
          message: 'Error al obtener preview del informe',
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getPreview', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/monthly-reports/enrollment/:enrollmentId ────────────────

  @override
  Future<List<MonthlyReportModel>> getReportsByEnrollment(
      int enrollmentId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.monthlyReports}/enrollment/$enrollmentId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final list = _unwrapList(response.data);
        return list.map(MonthlyReportModel.fromJson).toList();
      }

      throw ServerException(
          message: 'Error al obtener informes mensuales',
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getReportsByEnrollment', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/monthly-reports/:reportId ────────────────────────────────

  @override
  Future<MonthlyReportModel> getReportDetail(int reportId, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.monthlyReports}/$reportId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return MonthlyReportModel.fromJson(_unwrapData(response.data));
      }

      throw ServerException(
          message: 'Error al obtener detalle del informe',
          code: response.statusCode);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getReportDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/monthly-reports/:reportId/pdf ────────────────────────────

  @override
  Future<String> downloadReportPdf(int reportId, {CancelToken? cancelToken}) async {
    try {
      final dir = await getTemporaryDirectory();
      final filename =
          'sacdia_report_${reportId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$filename';

      // Download PDF bytes via the authenticated Dio client.
      // AuthInterceptor will attach the Bearer token in the Authorization
      // header, so the JWT never appears in the URL or query parameters.
      await _dio.download(
        '$_baseUrl${ApiEndpoints.monthlyReports}/$reportId/pdf',
        filePath,
        cancelToken: cancelToken,
        options: Options(
          // responseType is intentionally omitted: Dio.download() always
          // streams the response body to disk and ignores responseType.
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final file = File(filePath);
      if (!await file.exists() || await file.length() == 0) {
        throw ServerException(message: 'El archivo PDF descargado está vacío');
      }

      return filePath;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en downloadReportPdf', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
