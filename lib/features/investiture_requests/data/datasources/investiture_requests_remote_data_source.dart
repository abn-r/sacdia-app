import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../investiture/data/datasources/investiture_remote_data_source.dart'
    show extractInvestitureListFromResponse;
import '../../domain/entities/investiture_resolution.dart';
import '../investiture_request_error_keys.dart';
import '../models/investiture_request_model.dart';
import '../models/investiture_resolution_model.dart';
import '../models/json_parsing.dart';
import '../models/own_investiture_entry_model.dart';
import '../models/presentation_context_model.dart';
import '../models/yearbook_entry_model.dart';

/// Fuente de datos remota de la investidura por autorización.
abstract class InvestitureRequestsRemoteDataSource {
  /// GET /club-sections/{sectionId}/investiture-requests/presentation-context
  Future<PresentationContextModel> getPresentationContext(
    int sectionId,
    int yearId, {
    CancelToken? cancelToken,
  });

  /// GET /club-sections/{sectionId}/investiture-requests
  ///
  /// `null` cuando la sección no tiene pendientes en ese año.
  Future<InvestitureRequestModel?> getSectionRequest(
    int sectionId,
    int yearId, {
    CancelToken? cancelToken,
  });

  /// POST /club-sections/{sectionId}/investiture-requests
  Future<InvestitureRequestModel> present({
    required int sectionId,
    required int yearId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  });

  /// POST /investiture-requests/{requestId}/people
  Future<InvestitureRequestModel> addPeople({
    required String requestId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  });

  /// DELETE /investiture-requests/{requestId}/people/{personId}
  Future<RequestPersonModel> removePerson({
    required String requestId,
    required String personId,
  });

  /// PATCH /investiture-requests/{requestId}/dates
  Future<InvestitureRequestModel> changeDates({
    required String requestId,
    required DateTime investitureDate,
    required List<String> personIds,
  });

  /// GET /investiture-history
  Future<List<OwnInvestitureEntryModel>> getOwnHistory({
    CancelToken? cancelToken,
  });

  /// GET /club-sections/{sectionId}/investiture-history
  Future<List<OwnInvestitureEntryModel>> getSectionHistory(
    int sectionId, {
    CancelToken? cancelToken,
  });

  /// GET /club-sections/{sectionId}/investiture-yearbook
  Future<List<YearbookEntryModel>> getSectionYearbook(
    int sectionId, {
    CancelToken? cancelToken,
  });

  /// GET /investiture-requests?ecclesiastical_year_id= (autorizador)
  Future<List<InvestitureRequestModel>> listForAuthorizer(
    int yearId, {
    CancelToken? cancelToken,
  });

  /// GET /investiture-requests/{requestId} (autorizador)
  Future<InvestitureRequestModel> readForAuthorizer(
    String requestId, {
    CancelToken? cancelToken,
  });

  /// POST /investiture-requests/{requestId}/resolutions (autorizador)
  Future<InvestitureResolutionModel> resolve({
    required String requestId,
    List<InvestDecision> invest = const [],
    List<RejectDecision> reject = const [],
  });
}

class InvestitureRequestsRemoteDataSourceImpl
    implements InvestitureRequestsRemoteDataSource {
  InvestitureRequestsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'InvestitureRequestsDS';

  // ── Errores ────────────────────────────────────────────────────────────────

  Never _rethrow(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final errorCode = _extractDioCode(e);
      final mapped = investitureRequestErrorMessage(errorCode);

      if (mapped != null) {
        if (status == 403) {
          throw AuthException(message: mapped, code: status);
        }
        throw ServerException(message: mapped, code: status);
      }
      if (status == 403) {
        throw AuthException(
          message: tr('investiture_requests.errors.forbidden'),
          code: status,
        );
      }
      final msg = _extractDioMessage(e);
      throw ServerException(
        message:
            msg.isNotEmpty ? msg : tr('investiture_requests.errors.generic'),
        code: status,
      );
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: tr('investiture_requests.errors.generic'));
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        if (message is List) return message.join(', ');
        return message.toString();
      }
    } catch (err) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: err);
    }
    return e.message ?? tr('common.error_network');
  }

  String? _extractDioCode(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['code']?.toString();
    } catch (err) {
      AppLogger.w('Error al parsear código de error', tag: _tag, error: err);
    }
    return null;
  }

  // ── Helpers de respuesta ───────────────────────────────────────────────────

  /// Desenvuelve `{status, data}`; si la respuesta ya es el objeto, lo devuelve.
  dynamic _unwrap(Response<dynamic> response) {
    final raw = response.data;
    if (raw is Map && raw.containsKey('data') && raw.containsKey('status')) {
      return raw['data'];
    }
    return raw;
  }

  bool _isSuccess(Response<dynamic> response) {
    final code = response.statusCode;
    return code != null && code >= 200 && code < 300;
  }

  Map<String, dynamic> _requireMap(Response<dynamic> response) {
    if (!_isSuccess(response)) {
      throw ServerException(
        message: tr('investiture_requests.errors.generic'),
        code: response.statusCode,
      );
    }
    final data = _unwrap(response);
    if (data is Map) return asJsonMap(data);
    throw ServerException(
      message: tr('investiture_requests.errors.generic'),
      code: response.statusCode,
    );
  }

  List<dynamic> _requireList(
    Response<dynamic> response,
    String nestedKey,
  ) {
    if (!_isSuccess(response)) {
      throw ServerException(
        message: tr('investiture_requests.errors.generic'),
        code: response.statusCode,
      );
    }
    return extractInvestitureListFromResponse(response.data, nestedKey);
  }

  // ── Directiva de la sección ────────────────────────────────────────────────

  @override
  Future<PresentationContextModel> getPresentationContext(
    int sectionId,
    int yearId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/club-sections/$sectionId/investiture-requests/presentation-context',
        queryParameters: {'ecclesiastical_year_id': yearId},
        cancelToken: cancelToken,
      );
      return PresentationContextModel.fromJson(
        _requireMap(response),
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getPresentationContext', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<InvestitureRequestModel?> getSectionRequest(
    int sectionId,
    int yearId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/club-sections/$sectionId/investiture-requests',
        queryParameters: {'ecclesiastical_year_id': yearId},
        cancelToken: cancelToken,
      );
      if (!_isSuccess(response)) {
        throw ServerException(
          message: tr('investiture_requests.errors.generic'),
          code: response.statusCode,
        );
      }
      final data = _unwrap(response);
      if (data is! Map) return null;
      return InvestitureRequestModel.fromJson(asJsonMap(data));
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getSectionRequest', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<InvestitureRequestModel> present({
    required int sectionId,
    required int yearId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/club-sections/$sectionId/investiture-requests',
        data: {
          'ecclesiastical_year_id': yearId,
          'investiture_date': formatCivilDate(investitureDate),
          'enrollment_ids': enrollmentIds,
        },
      );
      return InvestitureRequestModel.fromJson(_requireMap(response));
    } catch (e) {
      AppLogger.e('Error en present', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<InvestitureRequestModel> addPeople({
    required String requestId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/investiture-requests/$requestId/people',
        data: {
          'investiture_date': formatCivilDate(investitureDate),
          'enrollment_ids': enrollmentIds,
        },
      );
      return InvestitureRequestModel.fromJson(
        _requireMap(response),
      );
    } catch (e) {
      AppLogger.e('Error en addPeople', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<RequestPersonModel> removePerson({
    required String requestId,
    required String personId,
  }) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl/investiture-requests/$requestId/people/$personId',
      );
      return RequestPersonModel.fromJson(_requireMap(response));
    } catch (e) {
      AppLogger.e('Error en removePerson', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<InvestitureRequestModel> changeDates({
    required String requestId,
    required DateTime investitureDate,
    required List<String> personIds,
  }) async {
    try {
      final response = await _dio.patch(
        '$_baseUrl/investiture-requests/$requestId/dates',
        data: {
          'investiture_date': formatCivilDate(investitureDate),
          'person_ids': personIds,
        },
      );
      return InvestitureRequestModel.fromJson(
        _requireMap(response),
      );
    } catch (e) {
      AppLogger.e('Error en changeDates', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Historial y anuario ────────────────────────────────────────────────────

  @override
  Future<List<OwnInvestitureEntryModel>> getOwnHistory({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/investiture-history',
        cancelToken: cancelToken,
      );
      return _requireList(response, 'history')
          .whereType<Map>()
          .map((j) => OwnInvestitureEntryModel.fromJson(asJsonMap(j)))
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getOwnHistory', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<OwnInvestitureEntryModel>> getSectionHistory(
    int sectionId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/club-sections/$sectionId/investiture-history',
        cancelToken: cancelToken,
      );
      return _requireList(response, 'history')
          .whereType<Map>()
          .map((j) => OwnInvestitureEntryModel.fromJson(asJsonMap(j)))
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getSectionHistory', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<YearbookEntryModel>> getSectionYearbook(
    int sectionId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/club-sections/$sectionId/investiture-yearbook',
        cancelToken: cancelToken,
      );
      return _requireList(response, 'entries')
          .whereType<Map>()
          .map((j) => YearbookEntryModel.fromJson(asJsonMap(j)))
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getSectionYearbook', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Autorizador ────────────────────────────────────────────────────────────

  @override
  Future<List<InvestitureRequestModel>> listForAuthorizer(
    int yearId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/investiture-requests',
        queryParameters: {'ecclesiastical_year_id': yearId},
        cancelToken: cancelToken,
      );
      return _requireList(response, 'requests')
          .whereType<Map>()
          .map((j) => InvestitureRequestModel.fromJson(asJsonMap(j)))
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en listForAuthorizer', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<InvestitureRequestModel> readForAuthorizer(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/investiture-requests/$requestId',
        cancelToken: cancelToken,
      );
      return InvestitureRequestModel.fromJson(
        _requireMap(response),
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en readForAuthorizer', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<InvestitureResolutionModel> resolve({
    required String requestId,
    List<InvestDecision> invest = const [],
    List<RejectDecision> reject = const [],
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/investiture-requests/$requestId/resolutions',
        data: {
          'invest': [
            for (final d in invest)
              {
                'person_id': d.personId,
                if (d.comment != null && d.comment!.trim().isNotEmpty)
                  'comment': d.comment!.trim(),
              },
          ],
          'reject': [
            for (final d in reject)
              {'person_id': d.personId, 'reason': d.reason.trim()},
          ],
        },
      );
      return InvestitureResolutionModel.fromJson(
        _requireMap(response),
      );
    } catch (e) {
      AppLogger.e('Error en resolve', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
