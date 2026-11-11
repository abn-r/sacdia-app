import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/service_credential.dart';
import '../../domain/entities/service_credential_review.dart';
import '../models/service_credential_model.dart';

const String _tag = 'ServiceCredentialsDS';

/// Fuente remota de constancias de servicio.
abstract class ServiceCredentialsRemoteDataSource {
  Future<List<ServiceCredential>> getMine();

  /// `POST` (registro) -> `PUT` a la URL firmada -> `POST .../confirm`.
  ///
  /// Si algo falla después del registro la constancia queda sin archivo: se
  /// intenta retirar (mejor esfuerzo) para que reintentar no choque con
  /// `SERVICE_CREDENTIAL_PENDING_EXISTS`.
  Future<ServiceCredential> submit({
    required ServiceCredentialDraft draft,
    required ConsentEvidenceLocalFile file,
    void Function(ServiceCredentialSubmitPhase phase)? onPhase,
    void Function(double progress)? onProgress,
  });

  Future<void> withdraw(String id);

  Future<ReviewPage> getReviewQueue({
    required ReviewStatusFilter status,
    String search = '',
    int page = 1,
    int limit = 20,
  });

  Future<ReviewDetail> getReviewDetail(String id);

  Future<void> approve(String id, {DateTime? expiresAt});

  Future<void> reject(String id, {required String reason});
}

class ServiceCredentialsRemoteDataSourceImpl
    implements ServiceCredentialsRemoteDataSource {
  ServiceCredentialsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
    Dio? uploadDio,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        // Dio plano: la URL firmada de R2 NO lleva Authorization ni pasa por
        // los interceptores de la API.
        _uploadDio = uploadDio ?? Dio();

  final Dio _dio;
  final Dio _uploadDio;
  final String _baseUrl;

  String get _minePath => '$_baseUrl/users/me/service-credentials';
  String get _reviewPath => '$_baseUrl/service-credentials/review';

  /// «Mis constancias» es de la propia persona: jamás lleva `X-Acting-For`.
  static final Options _selfOptions =
      Options(extra: {AuthInterceptor.skipActingForKey: true});

  Future<T> _call<T>(
    String label,
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic> body) parse,
  ) async {
    try {
      final response = await request();
      final status = response.statusCode;
      if (status == null || status < 200 || status >= 300) {
        throw appExceptionFromResponse(status, response.data);
      }
      final body = response.data;
      if (body is! Map) {
        // Un 204 sin cuerpo es válido para las acciones sin resultado.
        return parse(const <String, dynamic>{});
      }
      return parse(Map<String, dynamic>.from(body));
    } catch (e) {
      AppLogger.e('Error en $label', tag: _tag, error: e);
      rethrowApiError(e);
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ServerException(message: tr('errors.server_error'));
  }

  @override
  Future<List<ServiceCredential>> getMine() => _call(
        'getMine',
        () => _dio.get(_minePath, options: _selfOptions),
        (body) => serviceCredentialListFromData(body['data']),
      );

  @override
  Future<ServiceCredential> submit({
    required ServiceCredentialDraft draft,
    required ConsentEvidenceLocalFile file,
    void Function(ServiceCredentialSubmitPhase phase)? onPhase,
    void Function(double progress)? onProgress,
  }) async {
    onPhase?.call(ServiceCredentialSubmitPhase.registering);
    final ticket = await _call(
      'registerCredential',
      () => _dio.post(
        _minePath,
        data: {
          'type': kCounselorTrainingType,
          'completed_at': formatApiDate(draft.completedAt),
          'file_name': file.name,
          'mime_type': file.mimeType,
          'size_bytes': file.sizeBytes,
        },
        options: _selfOptions,
      ),
      (body) => ServiceCredentialTicket.fromJson(_data(body)),
    );
    final id = ticket.credential.id;
    try {
      onPhase?.call(ServiceCredentialSubmitPhase.uploading);
      await _putToSignedUrl(ticket, file, onProgress);
      onPhase?.call(ServiceCredentialSubmitPhase.confirming);
      return await _call(
        'confirmCredential',
        () => _dio.post('$_minePath/$id/confirm', options: _selfOptions),
        (body) => serviceCredentialFromJson(_data(body)),
      );
    } catch (e) {
      await _discard(id);
      rethrowApiError(e);
    }
  }

  Future<void> _putToSignedUrl(
    ServiceCredentialTicket ticket,
    ConsentEvidenceLocalFile file,
    void Function(double progress)? onProgress,
  ) async {
    final bytes = await File(file.path).readAsBytes();
    final headers = <String, dynamic>{
      'Content-Type': file.mimeType,
      'Content-Length': bytes.length.toString(),
      ...ticket.uploadHeaders,
    }
      // Nunca va el token de la API a una URL firmada de R2.
      ..remove('Authorization')
      ..remove('authorization');
    try {
      await _uploadDio.request<void>(
        ticket.uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          method: ticket.uploadMethod,
          headers: headers,
          followRedirects: false,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
    } on DioException catch (e) {
      final isNetwork = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      if (isNetwork) rethrow;
      // R2 answered an error (expired or rejected URL): it is not an auth
      // failure of the API session, it is a file that did not land.
      throw ServerException(
        message: e.message ?? tr('errors.server_error'),
        code: e.response?.statusCode,
        errorCode: 'SERVICE_CREDENTIAL_UPLOAD_MISSING',
      );
    }
  }

  /// Retira la constancia que se quedó sin archivo. Mejor esfuerzo.
  Future<void> _discard(String id) async {
    try {
      await _dio.delete('$_minePath/$id', options: _selfOptions);
    } catch (e) {
      AppLogger.e('No se pudo retirar la constancia $id', tag: _tag, error: e);
    }
  }

  @override
  Future<void> withdraw(String id) => _call(
        'withdraw',
        () => _dio.delete('$_minePath/$id', options: _selfOptions),
        (_) {},
      );

  @override
  Future<ReviewPage> getReviewQueue({
    required ReviewStatusFilter status,
    String search = '',
    int page = 1,
    int limit = 20,
  }) =>
      _call(
        'getReviewQueue',
        () => _dio.get(
          _reviewPath,
          queryParameters: {
            'status': status.apiValue,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            'page': page,
            'limit': limit,
          },
        ),
        reviewPageFromBody,
      );

  @override
  Future<ReviewDetail> getReviewDetail(String id) => _call(
        'getReviewDetail',
        () => _dio.get('$_reviewPath/$id'),
        (body) => reviewDetailFromData(_data(body)),
      );

  @override
  Future<void> approve(String id, {DateTime? expiresAt}) => _call(
        'approve',
        () => _dio.post(
          '$_reviewPath/$id/approve',
          data: {if (expiresAt != null) 'expires_at': formatApiDate(expiresAt)},
        ),
        (_) {},
      );

  @override
  Future<void> reject(String id, {required String reason}) => _call(
        'reject',
        () => _dio.post('$_reviewPath/$id/reject', data: {'reason': reason}),
        (_) {},
      );
}
