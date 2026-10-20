import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../post_registration/data/models/relationship_type_model.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/entities/dependent_progress_summary.dart';
import '../../domain/entities/supervised_login.dart';
import '../../domain/repositories/family_repository.dart';
import '../models/dependent_models.dart';

/// Fuente remota de `/guardianships`.
abstract class FamilyRemoteDataSource {
  Future<FamilyOverview> listDependents();

  /// Parentescos que el tutor puede declarar con un menor («yo soy su…»), en
  /// el orden del servidor. NO es el catálogo completo de
  /// `/catalogs/relationship-types` (ese sigue siendo el de contactos de
  /// emergencia).
  Future<List<RelationshipTypeModel>> getRelationshipTypes();

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

  Future<ConsentEvidenceReceipt> uploadConsentEvidence({
    required String dependentId,
    required ConsentEvidenceLocalFile file,
  });

  Future<ConsentEvidenceAccess> getConsentEvidence(String dependentId);

  Future<SupervisedLoginStatus> getSupervisedLogin(String dependentId);

  Future<EnabledSupervisedLogin> enableSupervisedLogin({
    required String dependentId,
    required SupervisedLoginMethod method,
    required String password,
    String? email,
  });

  Future<SupervisedLoginInfo> disableSupervisedLogin({
    required String dependentId,
    String? reason,
  });

  Future<SupervisedLoginInfo> reactivateSupervisedLogin({
    required String dependentId,
    String? password,
  });

  Future<PasswordResetResult> resetSupervisedPassword({
    required String dependentId,
    String? password,
  });

  Future<DependentProgressSummary> getProgressSummary(String dependentId);
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

  Future<T> _run<T>(
    String label,
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic> data) parse,
  ) async {
    try {
      final response = await request();
      if (!_isOk(response)) {
        throw appExceptionFromResponse(response.statusCode, response.data);
      }
      return parse(_unwrap(response.data));
    } catch (e) {
      AppLogger.e('Error en $label', tag: _tag, error: e);
      rethrowApiError(e);
    }
  }

  @override
  Future<List<RelationshipTypeModel>> getRelationshipTypes() async {
    try {
      final response = await _dio.get(
        '$_root/relationship-types',
        options: _options,
      );
      if (!_isOk(response)) {
        throw appExceptionFromResponse(response.statusCode, response.data);
      }
      final raw = response.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List ? raw['data'] as List : null);
      if (list == null) {
        throw ServerException(message: tr('errors.server_error'));
      }
      return [
        for (final item in list)
          if (item is Map)
            RelationshipTypeModel.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (e) {
      AppLogger.e('Error en getRelationshipTypes', tag: _tag, error: e);
      rethrowApiError(e);
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

  @override
  Future<ConsentEvidenceReceipt> uploadConsentEvidence({
    required String dependentId,
    required ConsentEvidenceLocalFile file,
  }) =>
      _run(
        'uploadConsentEvidence',
        () async => _dio.post(
          '$_root/me/dependents/$dependentId/consent-evidence',
          data: await file.toFormData(),
          options: Options(
            // Sin `X-Acting-For`: el tutor sube la ficha desde su perfil
            // propio (la ruta no lleva ActingScope).
            extra: const {AuthInterceptor.skipActingForKey: true},
            headers: const {'Content-Type': 'multipart/form-data'},
            sendTimeout: const Duration(minutes: 2),
            receiveTimeout: const Duration(minutes: 2),
          ),
        ),
        ConsentEvidenceJson.receipt,
      );

  @override
  Future<ConsentEvidenceAccess> getConsentEvidence(String dependentId) => _run(
        'getConsentEvidence',
        () => _dio.get(
          '$_root/me/dependents/$dependentId/consent-evidence',
          options: _options,
        ),
        ConsentEvidenceJson.access,
      );

  String _login(String dependentId) =>
      '$_root/me/dependents/$dependentId/supervised-login';

  @override
  Future<SupervisedLoginStatus> getSupervisedLogin(String dependentId) => _run(
        'getSupervisedLogin',
        () => _dio.get(_login(dependentId), options: _options),
        FamilyJson.supervisedLoginStatus,
      );

  @override
  Future<EnabledSupervisedLogin> enableSupervisedLogin({
    required String dependentId,
    required SupervisedLoginMethod method,
    required String password,
    String? email,
  }) =>
      _run(
        // El cuerpo lleva la contraseña: ni se registra ni se audita aquí.
        'enableSupervisedLogin',
        () => _dio.post(
          _login(dependentId),
          data: {
            'method': method.wire,
            if (method == SupervisedLoginMethod.email) 'email': email,
            'password': password,
          },
          options: _options,
        ),
        FamilyJson.enabledLogin,
      );

  @override
  Future<SupervisedLoginInfo> disableSupervisedLogin({
    required String dependentId,
    String? reason,
  }) =>
      _run(
        'disableSupervisedLogin',
        () => _dio.post(
          '${_login(dependentId)}/disable',
          data: {
            if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
          },
          options: _options,
        ),
        FamilyJson.loginInfoFromEnvelope,
      );

  @override
  Future<SupervisedLoginInfo> reactivateSupervisedLogin({
    required String dependentId,
    String? password,
  }) =>
      _run(
        'reactivateSupervisedLogin',
        () => _dio.post(
          '${_login(dependentId)}/reactivate',
          data: {if (password != null) 'password': password},
          options: _options,
        ),
        FamilyJson.loginInfoFromEnvelope,
      );

  @override
  Future<PasswordResetResult> resetSupervisedPassword({
    required String dependentId,
    String? password,
  }) =>
      _run(
        'resetSupervisedPassword',
        () => _dio.post(
          '${_login(dependentId)}/password',
          data: {if (password != null) 'password': password},
          options: _options,
        ),
        FamilyJson.passwordReset,
      );

  @override
  Future<DependentProgressSummary> getProgressSummary(String dependentId) =>
      _run(
        'getProgressSummary',
        () => _dio.get(
          '$_root/me/dependents/$dependentId/summary',
          options: _options,
        ),
        FamilyJson.progressSummary,
      );
}
