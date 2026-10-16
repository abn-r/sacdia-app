import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/legal_document_model.dart';
import '../models/legal_status_model.dart';

/// Interfaz del data source remoto legal.
abstract class LegalRemoteDataSource {
  /// GET /legal/current -> `data.documents`
  Future<List<LegalDocumentModel>> getCurrentDocuments();

  /// GET /users/me/legal-acceptance -> `data`
  Future<LegalStatusModel> getMyStatus();

  /// POST /users/me/legal-acceptance -> `data`
  ///
  /// Body `{terms_version, privacy_version}`. Un 400 con
  /// `code: LEGAL_VERSION_MISMATCH` llega como [ServerException.errorCode].
  Future<LegalStatusModel> accept({
    required String termsVersion,
    required String privacyVersion,
  });
}

/// Implementación del data source remoto legal.
class LegalRemoteDataSourceImpl implements LegalRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'LegalDS';

  LegalRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String get _myAcceptanceUrl =>
      '$_baseUrl${ApiEndpoints.users}/me/legal-acceptance';

  /// Extrae `data` del envelope `{status, data}`.
  Map<String, dynamic> _unwrapData(Object? raw) {
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    throw ServerException(message: tr('errors.server_error'));
  }

  /// Convierte un error de transporte o HTTP en una excepción tipada que
  /// conserva el `code` de negocio del backend en [AppException.errorCode].
  Never _rethrow(Object e) {
    if (e is AppException) throw e;
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw ConnectionException(
          message: e.message ?? tr('errors.connection_error'),
          stackTrace: e.stackTrace,
        );
      }
      throw _fromResponse(e.response?.statusCode, e.response?.data,
          fallback: e.message);
    }
    throw ServerException(message: e.toString());
  }

  AppException _fromResponse(int? status, Object? data, {String? fallback}) {
    String? message;
    String? errorCode;
    if (data is Map) {
      message = data['message']?.toString();
      errorCode = data['code']?.toString();
    }
    final resolved = message ?? fallback ?? tr('errors.server_error');
    if (status == 401 || status == 403) {
      return AuthException(
          message: resolved, code: status, errorCode: errorCode);
    }
    return ServerException(
        message: resolved, code: status, errorCode: errorCode);
  }

  bool _isOk(Response<dynamic> r) =>
      r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

  @override
  Future<List<LegalDocumentModel>> getCurrentDocuments() async {
    try {
      final response = await _dio.get('$_baseUrl${ApiEndpoints.legal}/current');
      if (!_isOk(response)) {
        throw _fromResponse(response.statusCode, response.data);
      }
      final docs = _unwrapData(response.data)['documents'];
      if (docs is! List) {
        throw ServerException(message: tr('errors.server_error'));
      }
      return docs
          .map((d) => LegalDocumentModel.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error en getCurrentDocuments', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<LegalStatusModel> getMyStatus() async {
    try {
      final response = await _dio.get(_myAcceptanceUrl);
      if (!_isOk(response)) {
        throw _fromResponse(response.statusCode, response.data);
      }
      return LegalStatusModel.fromJson(_unwrapData(response.data));
    } catch (e) {
      AppLogger.e('Error en getMyStatus', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<LegalStatusModel> accept({
    required String termsVersion,
    required String privacyVersion,
  }) async {
    try {
      final response = await _dio.post(
        _myAcceptanceUrl,
        data: {
          'terms_version': termsVersion,
          'privacy_version': privacyVersion,
        },
      );
      if (!_isOk(response)) {
        throw _fromResponse(response.statusCode, response.data);
      }
      return LegalStatusModel.fromJson(_unwrapData(response.data));
    } catch (e) {
      AppLogger.e('Error en accept', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
