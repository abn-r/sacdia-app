import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/repositories/family_repository.dart';
import '../models/dependent_models.dart';

/// Fuente remota de `/guardianships`.
abstract class FamilyRemoteDataSource {
  Future<FamilyOverview> listDependents();

  Future<DependentDetail> getDependent(String dependentId);

  Future<DependentSummary> createDependent(CreateDependentInput input);

  Future<IssuedLinkCode> issueLinkCode(String dependentId);

  Future<DependentSummary> redeemLinkCode({
    required String code,
    required String relationshipTypeId,
    required bool swornDeclaration,
  });

  Future<RevokeResult> revoke({
    required String guardianshipId,
    required bool removedByPrimary,
  });

  Future<List<DeletionImpactEntry>> deletionImpact();
}

class FamilyRemoteDataSourceImpl implements FamilyRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'FamilyDS';

  FamilyRemoteDataSourceImpl({required Dio dio, required String baseUrl})
      : _dio = dio,
        _baseUrl = baseUrl;

  String get _root => '$_baseUrl${ApiEndpoints.guardianships}';

  /// Mi familia se gestiona desde el perfil PROPIO del tutor: ninguna llamada
  /// lleva `X-Acting-For`, aunque `/guardianships` ya esté en la lista de
  /// exentas del interceptor (cinturón y tirantes).
  Options get _options =>
      Options(extra: const {AuthInterceptor.skipActingForKey: true});

  Map<String, dynamic> _unwrap(Object? raw) {
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    throw ServerException(message: tr('errors.server_error'));
  }

  bool _isOk(Response<dynamic> r) =>
      r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

  /// Convierte el error en una excepción tipada que conserva el `code` de
  /// negocio. `details` no se lee nunca: el backend lo omite en producción.
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
      // El ErrorInterceptor ya tradujo el error; si trae uno nuestro, se
      // respeta su tipo pero se rescata el `code` de la respuesta.
      throw _fromResponse(
        e.response?.statusCode,
        e.response?.data,
        fallback: e.message,
      );
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
        message: resolved,
        code: status,
        errorCode: errorCode,
      );
    }
    return ServerException(
      message: resolved,
      code: status,
      errorCode: errorCode,
    );
  }

  Future<T> _run<T>(
    String label,
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic> data) parse,
  ) async {
    try {
      final response = await request();
      if (!_isOk(response)) {
        throw _fromResponse(response.statusCode, response.data);
      }
      return parse(_unwrap(response.data));
    } catch (e) {
      AppLogger.e('Error en $label', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<FamilyOverview> listDependents() => _run(
        'listDependents',
        () => _dio.get('$_root/me/dependents', options: _options),
        FamilyJson.overview,
      );

  @override
  Future<DependentDetail> getDependent(String dependentId) => _run(
        'getDependent',
        () => _dio.get('$_root/me/dependents/$dependentId', options: _options),
        FamilyJson.detail,
      );

  @override
  Future<DependentSummary> createDependent(CreateDependentInput input) => _run(
        'createDependent',
        () => _dio.post(
          '$_root/me/dependents',
          data: {
            'name': input.name,
            'paternal_last_name': input.paternalLastName,
            if (input.maternalLastName != null &&
                input.maternalLastName!.trim().isNotEmpty)
              'maternal_last_name': input.maternalLastName,
            'birthday': input.birthday,
            'relationship_type_id': input.relationshipTypeId,
            'sworn_declaration': input.swornDeclaration,
            'accepted_terms_version': input.acceptedTermsVersion,
            'accepted_privacy_version': input.acceptedPrivacyVersion,
          },
          options: _options,
        ),
        FamilyJson.summary,
      );

  @override
  Future<IssuedLinkCode> issueLinkCode(String dependentId) => _run(
        'issueLinkCode',
        () => _dio.post(
          '$_root/me/dependents/$dependentId/link-codes',
          data: const {'purpose': 'second_guardian'},
          options: _options,
        ),
        FamilyJson.linkCode,
      );

  @override
  Future<DependentSummary> redeemLinkCode({
    required String code,
    required String relationshipTypeId,
    required bool swornDeclaration,
  }) =>
      _run(
        'redeemLinkCode',
        () => _dio.post(
          '$_root/link-codes/redeem',
          data: {
            'code': code,
            'relationship_type_id': relationshipTypeId,
            'sworn_declaration': swornDeclaration,
          },
          options: _options,
        ),
        FamilyJson.summary,
      );

  @override
  Future<RevokeResult> revoke({
    required String guardianshipId,
    required bool removedByPrimary,
  }) =>
      _run(
        'revoke',
        () => _dio.post(
          '$_root/$guardianshipId/revoke',
          data: {
            'reason': removedByPrimary ? 'removed_by_primary' : 'guardian_left',
          },
          options: _options,
        ),
        FamilyJson.revoke,
      );

  @override
  Future<List<DeletionImpactEntry>> deletionImpact() => _run(
        'deletionImpact',
        () => _dio.get('$_root/me/deletion-impact', options: _options),
        FamilyJson.deletionImpact,
      );
}
