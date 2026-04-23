import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/support_report.dart';

/// Fuente remota para enviar reportes de soporte al backend.
abstract class SupportRemoteDataSource {
  /// POST /api/v1/support/reports
  ///
  /// Lanza:
  /// - [AuthException] en 401/403
  /// - [ValidationException] en 400
  /// - [ServerException] en 429 (rate-limit) o 5xx
  Future<SupportReportResult> submitReport(SupportReportDraft draft);
}

class SupportRemoteDataSourceImpl implements SupportRemoteDataSource {
  static const _tag = 'SupportRemoteDS';

  final Dio _dio;
  final String _baseUrl;

  SupportRemoteDataSourceImpl({required Dio dio, required String baseUrl})
      : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      final msg = _extractMessage(e);
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        throw AuthException(
          message: 'Tu sesión expiró. Iniciá sesión nuevamente.',
          code: code,
        );
      }
      if (code == 400) {
        throw ValidationException(message: msg);
      }
      // 429 se reporta como ServerException — la UI muestra el mensaje del
      // backend ("Rate limit exceeded") y sugiere reintentar más tarde.
      throw ServerException(message: msg, code: code);
    }
    if (e is AppException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        final raw = data['message'];
        if (raw is List) return raw.join(', ');
        if (raw is String) return raw;
      }
    } catch (_) {/* noop */}
    return e.message ?? 'Error de conexión';
  }

  @override
  Future<SupportReportResult> submitReport(SupportReportDraft draft) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/support/reports',
        data: draft.toJson(),
      );

      final status = response.statusCode ?? 0;
      if (status == 200 || status == 201) {
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          return SupportReportResult.fromJson(raw);
        }
        if (raw is Map) {
          return SupportReportResult.fromJson(
            raw.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      }

      throw ServerException(
        message: 'No pudimos enviar tu reporte',
        code: status,
      );
    } catch (e) {
      AppLogger.e('Error en submitReport', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
