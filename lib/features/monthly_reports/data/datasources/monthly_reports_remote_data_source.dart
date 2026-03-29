import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  });

  Future<List<MonthlyReportModel>> getReportsByEnrollment(int enrollmentId);

  Future<MonthlyReportModel> getReportDetail(int reportId);

  /// Devuelve la URL del PDF (redirige o devuelve una URL directa).
  Future<String> getReportPdfUrl(int reportId);
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
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.monthlyReports}/preview/$enrollmentId',
        queryParameters: {'month': month, 'year': year},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return MonthlyReportPreviewModel.fromJson(
            _unwrapData(response.data));
      }

      throw ServerException(
          message: 'Error al obtener preview del informe',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getPreview', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/monthly-reports/enrollment/:enrollmentId ────────────────

  @override
  Future<List<MonthlyReportModel>> getReportsByEnrollment(
      int enrollmentId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.monthlyReports}/enrollment/$enrollmentId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final list = _unwrapList(response.data);
        return list.map(MonthlyReportModel.fromJson).toList();
      }

      throw ServerException(
          message: 'Error al obtener informes mensuales',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getReportsByEnrollment', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/monthly-reports/:reportId ────────────────────────────────

  @override
  Future<MonthlyReportModel> getReportDetail(int reportId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.monthlyReports}/$reportId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return MonthlyReportModel.fromJson(_unwrapData(response.data));
      }

      throw ServerException(
          message: 'Error al obtener detalle del informe',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getReportDetail', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /api/v1/monthly-reports/:reportId/pdf ────────────────────────────

  @override
  Future<String> getReportPdfUrl(int reportId) async {
    try {
      // The PDF endpoint may return a redirect or a JSON with a url field.
      // We disable followRedirects to capture the Location header if present.
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.monthlyReports}/$reportId/pdf',
        options: Options(
          followRedirects: false,
          validateStatus: (status) =>
              status != null && (status < 400 || status == 302),
        ),
      );

      // If redirect (302), return the Location header
      if (response.statusCode == 302) {
        final location = response.headers.value('location');
        if (location != null) return location;
      }

      // If JSON response with url field
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map) {
          final url = data['url'] ?? data['pdf_url'] ?? data['download_url'];
          if (url != null) return url.toString();
        }
        // If data is directly a string URL
        if (data is String) return data;
      }

      // Fallback: build URL with token as query param (for direct browser/webview access)
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      final base = '$_baseUrl${ApiEndpoints.monthlyReports}/$reportId/pdf';
      return token != null ? '$base?token=$token' : base;
    } catch (e) {
      AppLogger.e('Error en getReportPdfUrl', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
