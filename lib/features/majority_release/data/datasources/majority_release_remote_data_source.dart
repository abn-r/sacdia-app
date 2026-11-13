import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/adult_claim_code.dart';
import '../../domain/entities/released_entry.dart';

/// Fuente remota de la liberación por mayoría de edad (Fase 4).
abstract class MajorityReleaseRemoteDataSource {
  Future<void> addEmail(String email);

  Future<void> redeemAdultClaim({
    required String code,
    required String email,
    required String password,
  });

  Future<List<ReleasedEntry>> getReleasedHistory();

  Future<IssuedAdultClaimCode> issueGuardianCode(String dependentId);

  Future<IssuedAdultClaimCode> issueDirectorCode({
    required int clubSectionId,
    required String dependentUserId,
  });
}

class MajorityReleaseRemoteDataSourceImpl
    implements MajorityReleaseRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'MajorityReleaseDS';

  MajorityReleaseRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  /// Estas llamadas son de la propia persona (o del ex tutor desde su perfil):
  /// ninguna lleva `X-Acting-For`.
  Options get _options =>
      Options(extra: const {AuthInterceptor.skipActingForKey: true});

  bool _isOk(Response<dynamic> r) =>
      r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

  /// `data` del envelope `{status, data}`; si no hay, el propio cuerpo.
  Map<String, dynamic> _dataOf(Object? raw) {
    if (raw is Map) {
      final inner = raw['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return Map<String, dynamic>.from(raw);
    }
    throw ServerException(message: tr('errors.server_error'));
  }

  Future<Response<dynamic>> _checked(
    String label,
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      if (!_isOk(response)) {
        throw appExceptionFromResponse(response.statusCode, response.data);
      }
      return response;
    } catch (e) {
      // Nunca se registra el cuerpo: lleva correo, contraseña o código.
      AppLogger.e('Error en $label', tag: _tag, error: e.runtimeType);
      rethrowApiError(e);
    }
  }

  @override
  Future<void> addEmail(String email) async {
    await _checked(
      'addEmail',
      () => _dio.post(
        '$_baseUrl${ApiEndpoints.users}/me/release/email',
        data: {'email': email},
        options: _options,
      ),
    );
  }

  @override
  Future<void> redeemAdultClaim({
    required String code,
    required String email,
    required String password,
  }) async {
    await _checked(
      'redeemAdultClaim',
      () => _dio.post(
        '$_baseUrl${ApiEndpoints.auth}/adult-claim/redeem',
        data: {'code': code, 'email': email, 'password': password},
        options: _options,
      ),
    );
  }

  @override
  Future<List<ReleasedEntry>> getReleasedHistory() async {
    final response = await _checked(
      'getReleasedHistory',
      () => _dio.get(
        '$_baseUrl${ApiEndpoints.guardianships}/me/history',
        options: _options,
      ),
    );
    final released = _dataOf(response.data)['released'];
    if (released is! List) return const [];
    return [
      for (final raw in released)
        if (raw is Map) _entry(Map<String, dynamic>.from(raw)),
    ];
  }

  static DateTime? _date(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  static String? _string(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  static ReleasedEntry _entry(Map<String, dynamic> json) => ReleasedEntry(
        guardianshipId: json['guardianship_id']?.toString() ?? '',
        dependentUserId: json['dependent_user_id']?.toString() ?? '',
        displayName: _string(json['display_name']),
        relationshipTypeName: _string(json['relationship_type_name']),
        releasedAt: _date(json['released_at']),
        canIssueClaim: json['can_issue_claim'] == true,
      );

  static IssuedAdultClaimCode _issued(Map<String, dynamic> json) =>
      IssuedAdultClaimCode(
        code: json['code'].toString(),
        // Vigencia fija de 14 días (sin plazo máximo); se puede regenerar en cualquier momento. Si no la informa, 14 días.
        expiresAt: _date(json['expires_at']) ??
            DateTime.now().add(const Duration(days: 14)),
      );

  @override
  Future<IssuedAdultClaimCode> issueGuardianCode(String dependentId) async {
    final response = await _checked(
      'issueGuardianCode',
      () => _dio.post(
        '$_baseUrl${ApiEndpoints.guardianships}/me/released/$dependentId/'
        'adult-claim-code',
        options: _options,
      ),
    );
    return _issued(_dataOf(response.data));
  }

  @override
  Future<IssuedAdultClaimCode> issueDirectorCode({
    required int clubSectionId,
    required String dependentUserId,
  }) async {
    final response = await _checked(
      'issueDirectorCode',
      () => _dio.post(
        '$_baseUrl${ApiEndpoints.clubSections}/$clubSectionId/dependents/'
        '$dependentUserId/adult-claim-codes',
      ),
    );
    return _issued(_dataOf(response.data));
  }
}
