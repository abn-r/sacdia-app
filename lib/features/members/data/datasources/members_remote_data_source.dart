import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/annual_continuation.dart';
import '../../domain/entities/assignable_role.dart';
import '../../domain/entities/consent_verification_result.dart';
import '../models/annual_continuation_model.dart';
import '../models/club_member_model.dart';
import '../models/join_request_model.dart';

/// Interfaz de la fuente de datos remota para miembros
abstract class MembersRemoteDataSource {
  /// Obtiene los miembros de una sección de club
  Future<List<ClubMemberModel>> getClubMembers({
    required int clubId,
    required int sectionId,
    CancelToken? cancelToken,
  });

  /// Obtiene el perfil de un miembro específico
  Future<ClubMemberModel> getMemberDetail(String userId,
      {CancelToken? cancelToken});

  /// Obtiene solicitudes de ingreso al club
  Future<List<JoinRequestModel>> getJoinRequests({
    required int clubId,
    required int sectionId,
    CancelToken? cancelToken,
  });

  /// Aprueba una solicitud de ingreso
  Future<JoinRequestModel> approveJoinRequest(String assignmentId);

  /// Rechaza una solicitud de ingreso
  Future<JoinRequestModel> rejectJoinRequest(String assignmentId);

  /// Asigna un rol a un miembro en una sección del club
  Future<bool> assignClubRole({
    required int clubId,
    required int sectionId,
    required String userId,
    required String role,
  });

  /// Roles de club con su elegibilidad para [userId] en la sección.
  Future<AssignableRolesResult> getAssignableRoles({
    required int clubId,
    required int sectionId,
    required String userId,
  });

  /// Remueve una asignación de rol
  Future<bool> removeClubRole(String assignmentId);

  /// No inscritos del año vigente. Requiere `club_members:approve`.
  Future<List<AnnualContinuationModel>> getAnnualContinuations(int sectionId);

  /// Inscribe no inscritos. Resultados por usuario.
  Future<ContinuationBatchResult> submitAnnualContinuations({
    required int sectionId,
    required List<String> userIds,
  });

  /// Sube la ficha firmada de un menor (director). Conserva el `code` de
  /// negocio en [AppException.errorCode].
  Future<ConsentEvidenceReceipt> uploadConsentEvidence({
    required String assignmentId,
    required ConsentEvidenceLocalFile file,
  });

  /// Ficha vigente con URL firmada.
  Future<ConsentEvidenceAccess> getConsentEvidence(String assignmentId);

  /// Verifica el consentimiento y, con [approve], aprueba la solicitud.
  Future<ConsentVerificationResult> verifyConsent({
    required String assignmentId,
    required bool approve,
  });
}

/// Implementación de la fuente de datos remota para miembros
class MembersRemoteDataSourceImpl implements MembersRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'MembersDS';

  MembersRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  /// Desenvuelve la respuesta de la API que puede venir como
  /// { "status": "success", "data": [...] } o directamente como [...]
  List<Map<String, dynamic>> _unwrapList(dynamic responseData) {
    if (responseData is List) {
      return responseData.cast<Map<String, dynamic>>();
    }
    if (responseData is Map) {
      final data = responseData['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      // Algunos endpoints anidan en { data: { members: [...] } }
      if (data is Map) {
        final members = data['members'] ?? data['items'] ?? data['results'];
        if (members is List) return members.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  Map<String, dynamic> _unwrapMap(dynamic responseData) {
    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);
      final data = map['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return map;
    }
    return {};
  }

  String _normalizeRoleKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
  }

  List<String> _roleLookupCandidates(String role) {
    final normalized = _normalizeRoleKey(role);
    const aliases = <String, List<String>>{
      'deputy-director': ['subdirector'],
      'subdirector': ['deputy-director'],
      'secretary': ['secretario'],
      'treasurer': ['tesorero'],
      'counselor': ['consejero'],
      'member': ['miembro'],
    };

    final values = <String>{normalized, ...(aliases[normalized] ?? const [])};
    return values.toList();
  }

  final Map<String, String> _clubRoleIdsByName = {};

  Future<String?> _resolveClubRoleId(String role) async {
    for (final candidate in _roleLookupCandidates(role)) {
      final cached = _clubRoleIdsByName[candidate];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/roles',
        queryParameters: const {'category': 'CLUB'},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return null;
      }

      final roles = _unwrapList(response.data);
      for (final roleRecord in roles) {
        // El catálogo público expone `name` (contrato normalizado);
        // `role_name` queda como fallback de respuestas legacy.
        final roleName =
            (roleRecord['name'] ?? roleRecord['role_name'])?.toString();
        final roleId = roleRecord['role_id']?.toString();

        if (roleName == null || roleId == null || roleId.isEmpty) {
          continue;
        }

        final normalizedName = _normalizeRoleKey(roleName);
        _clubRoleIdsByName[normalizedName] = roleId;
      }
    } on DioException catch (e) {
      AppLogger.w('No se pudo resolver role_id desde /catalogs/roles',
          tag: _tag, error: e);
      return null;
    }

    for (final candidate in _roleLookupCandidates(role)) {
      final resolved = _clubRoleIdsByName[candidate];
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }

    return null;
  }

  @override
  Future<List<ClubMemberModel>> getClubMembers({
    required int clubId,
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/members',
        cancelToken: cancelToken,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('members.errors.fetch_club_members'),
          code: response.statusCode,
        );
      }

      final list = _unwrapList(response.data);
      return list.map((json) => ClubMemberModel.fromJson(json)).toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error al obtener miembros', tag: _tag, error: e);
      throw ServerException(
        message:
            e.response?.data?['message'] ?? tr('members.errors.fetch_members'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getClubMembers', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ClubMemberModel> getMemberDetail(String userId,
      {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId',
        cancelToken: cancelToken,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('members.errors.fetch_member_detail'),
          code: response.statusCode,
        );
      }

      final json = _unwrapMap(response.data);
      return ClubMemberModel.fromJson(json);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error al obtener detalle del miembro', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ??
            tr('members.errors.fetch_member_detail'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getMemberDetail', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<JoinRequestModel>> getJoinRequests({
    required int clubId,
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubSections}/$sectionId${ApiEndpoints.membershipRequests}',
        cancelToken: cancelToken,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('members.errors.fetch_join_requests'),
          code: response.statusCode,
        );
      }

      final list = _unwrapList(response.data);
      return list.map((json) => JoinRequestModel.fromJson(json)).toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      // Si es 404 u otro error de recurso no encontrado, retornar lista vacía
      if (e.response?.statusCode == 404 || e.response?.statusCode == 400) {
        AppLogger.w('Endpoint de solicitudes no disponible', tag: _tag);
        return [];
      }
      AppLogger.e('Error al obtener solicitudes', tag: _tag, error: e);
      throw ServerException(
        message:
            e.response?.data?['message'] ?? tr('members.errors.fetch_requests'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getJoinRequests', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<JoinRequestModel> approveJoinRequest(String assignmentId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubSections}/$assignmentId/approve',
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('members.errors.approve_request'),
          code: response.statusCode,
        );
      }

      final json = _unwrapMap(response.data);
      return JoinRequestModel.fromJson({...json, 'status': 'approved'});
    } on DioException catch (e) {
      AppLogger.e('Error al aprobar solicitud', tag: _tag, error: e);
      final data = e.response?.data;
      throw ServerException(
        message: e.response?.data?['message'] ??
            tr('members.errors.approve_request'),
        code: e.response?.statusCode,
        // `MR_CONSENT_NOT_VERIFIED` (menor sin ficha verificada) se distingue
        // por código; `details` nunca se lee.
        errorCode: data is Map ? data['code']?.toString() : null,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<JoinRequestModel> rejectJoinRequest(String assignmentId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubSections}/$assignmentId/reject',
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('members.errors.reject_request'),
          code: response.statusCode,
        );
      }

      final json = _unwrapMap(response.data);
      return JoinRequestModel.fromJson({...json, 'status': 'rejected'});
    } on DioException catch (e) {
      AppLogger.e('Error al rechazar solicitud', tag: _tag, error: e);
      throw ServerException(
        message:
            e.response?.data?['message'] ?? tr('members.errors.reject_request'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<bool> assignClubRole({
    required int clubId,
    required int sectionId,
    required String userId,
    required String role,
  }) async {
    try {
      final roleId = await _resolveClubRoleId(role);
      final payload = <String, dynamic>{
        'user_id': userId,
        'club_section_id': sectionId,
        'start_date': DateTime.now().toIso8601String(),
      };

      if (roleId == null || roleId.isEmpty) {
        throw ServerException(
          message: 'No se pudo resolver role_id para la asignacion canonica',
        );
      }

      payload['role_id'] = roleId;

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/roles',
        data: payload,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      AppLogger.e('Error al asignar rol', tag: _tag, error: e);
      final data = e.response?.data;
      throw ServerException(
        message:
            e.response?.data?['message'] ?? tr('members.errors.assign_role'),
        code: e.response?.statusCode,
        // `MR_CONSENT_NOT_VERIFIED` (menor sin ficha verificada, 409) se
        // distingue por código; `details` nunca se lee.
        errorCode: data is Map ? data['code']?.toString() : null,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<AssignableRolesResult> getAssignableRoles({
    required int clubId,
    required int sectionId,
    required String userId,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/members/$userId/assignable-roles',
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('members.errors.fetch_assignable_roles'),
          code: response.statusCode,
        );
      }

      final result = AssignableRolesResult.fromJson(_unwrapMap(response.data));
      // Los role_id de este endpoint sirven directo al asignar; el catálogo
      // queda como respaldo.
      for (final role in result.roles) {
        if (role.roleId.isEmpty) continue;
        _clubRoleIdsByName[_normalizeRoleKey(role.roleName)] = role.roleId;
      }
      return result;
    } on DioException catch (e) {
      AppLogger.e('Error al obtener roles asignables', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ??
            tr('members.errors.fetch_assignable_roles'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<bool> removeClubRole(String assignmentId) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.clubRoles}/$assignmentId',
      );

      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } on DioException catch (e) {
      AppLogger.e('Error al remover rol', tag: _tag, error: e);
      throw ServerException(
        message:
            e.response?.data?['message'] ?? tr('members.errors.remove_role'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<AnnualContinuationModel>> getAnnualContinuations(
      int sectionId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubSections}/$sectionId${ApiEndpoints.annualContinuations}',
        queryParameters: const {'page': 1, 'limit': 100},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('members.continuations.errors.fetch'),
          code: response.statusCode,
        );
      }

      final list = unwrapAnnualContinuationItems(response.data);
      return list;
    } on DioException catch (e) {
      AppLogger.e('Error al obtener continuaciones anuales',
          tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ??
            tr('members.continuations.errors.fetch'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en getAnnualContinuations',
          tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ContinuationBatchResult> submitAnnualContinuations({
    required int sectionId,
    required List<String> userIds,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubSections}/$sectionId${ApiEndpoints.annualContinuations}',
        data: {'user_ids': userIds},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: tr('members.continuations.errors.submit'),
          code: response.statusCode,
        );
      }

      return ContinuationBatchResult.fromJson(_unwrapMap(response.data));
    } on DioException catch (e) {
      AppLogger.e('Error al enviar continuaciones', tag: _tag, error: e);
      throw ServerException(
        message: e.response?.data?['message'] ??
            tr('members.continuations.errors.submit'),
        code: e.response?.statusCode,
      );
    } catch (e) {
      if (e is AuthException || e is ServerException) rethrow;
      AppLogger.e('Error inesperado en submitAnnualContinuations',
          tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  // ── Consentimiento de menores (Phase 2c) ──────────────────────────────────
  //
  // `assignmentId` viene de [JoinRequest.assignmentId]: `<sectionId>/
  // membership-requests/<requestId>`, la misma ruta que usan approve/reject.
  // Estas rutas NO son acting-scoped: si el director estuviera "viendo como" un
  // menor, el encabezado `X-Acting-For` hace que el backend las rechace (403
  // ACTING_FOR_SCOPE_DENIED), que es lo correcto.

  Map<String, dynamic> _unwrapData(Object? raw) {
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    throw ServerException(message: tr('errors.server_error'));
  }

  Future<T> _consentCall<T>(
    String label,
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic> data) parse,
  ) async {
    try {
      final response = await request();
      final status = response.statusCode;
      if (status == null || status < 200 || status >= 300) {
        throw appExceptionFromResponse(status, response.data);
      }
      return parse(_unwrapData(response.data));
    } catch (e) {
      AppLogger.e('Error en $label', tag: _tag, error: e);
      rethrowApiError(e);
    }
  }

  String _consentPath(String assignmentId, String suffix) =>
      '$_baseUrl${ApiEndpoints.clubSections}/$assignmentId/$suffix';

  @override
  Future<ConsentEvidenceReceipt> uploadConsentEvidence({
    required String assignmentId,
    required ConsentEvidenceLocalFile file,
  }) =>
      _consentCall(
        'uploadConsentEvidence',
        () async => _dio.post(
          _consentPath(assignmentId, 'consent-evidence'),
          data: await file.toFormData(),
          options: Options(
            headers: const {'Content-Type': 'multipart/form-data'},
            sendTimeout: const Duration(minutes: 2),
            receiveTimeout: const Duration(minutes: 2),
          ),
        ),
        ConsentEvidenceJson.receipt,
      );

  @override
  Future<ConsentEvidenceAccess> getConsentEvidence(String assignmentId) =>
      _consentCall(
        'getConsentEvidence',
        () => _dio.get(_consentPath(assignmentId, 'consent-evidence')),
        ConsentEvidenceJson.access,
      );

  @override
  Future<ConsentVerificationResult> verifyConsent({
    required String assignmentId,
    required bool approve,
  }) =>
      _consentCall(
        'verifyConsent',
        () => _dio.post(
          _consentPath(assignmentId, 'verify-consent'),
          data: {
            'confirm_paper_form_reviewed': true,
            'approve': approve,
          },
        ),
        (data) {
          final guardianship = data['guardianship'];
          final g = guardianship is Map
              ? Map<String, dynamic>.from(guardianship)
              : const <String, dynamic>{};
          final rawError = data['approve_error'];
          return ConsentVerificationResult(
            guardianshipId: g['guardianship_id']?.toString() ?? '',
            verifiedAt: g['verified_at'] != null
                ? DateTime.tryParse(g['verified_at'].toString())
                : null,
            verifiedByUserId: g['verified_by_user_id']?.toString(),
            verificationMethod: g['verification_method']?.toString(),
            approved: data['assignment'] != null,
            approveError:
                rawError is String && rawError.isNotEmpty ? rawError : null,
          );
        },
      );
}
