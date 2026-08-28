import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/class_model.dart';
import '../models/class_module_model.dart';
import '../models/class_progress_model.dart';
import '../models/class_members_progress_result_model.dart';
import '../models/progress_scope_result_model.dart';
import '../models/class_with_progress_model.dart';
import '../models/class_counselor_assignment_model.dart';
import '../models/requirement_evidence_model.dart';
import '../models/class_honor_model.dart';

/// Interfaz para la fuente de datos remota de clases progresivas
abstract class ClassesRemoteDataSource {
  Future<List<ClassModel>> getClasses(
      {int? clubTypeId, CancelToken? cancelToken});
  Future<ClassModel> getClassById(int classId, {CancelToken? cancelToken});
  Future<List<ClassModuleModel>> getClassModules(int classId,
      {CancelToken? cancelToken});
  Future<List<ClassHonorModel>> getClassHonors(int classId,
      {CancelToken? cancelToken});
  Future<List<ClassModel>> getUserClasses(String userId,
      {CancelToken? cancelToken});
  Future<ClassProgressModel> getUserClassProgress(String userId, int classId,
      {int? enrollmentId, CancelToken? cancelToken});
  Future<ClassProgressModel> updateUserClassProgress(
      String userId, int classId, Map<String, dynamic> progressData,
      {int? enrollmentId});
  Future<ProgressScopeResultModel> getProgressScope(int clubId, int sectionId,
      {int? yearId, CancelToken? cancelToken});
  Future<ClassMembersProgressResultModel> getClassMembersProgress(
      int clubId, int sectionId, int classId,
      {int? yearId, CancelToken? cancelToken});
  Future<List<ClassCounselorAssignmentModel>> getClassCounselorAssignments(
    int clubId,
    int sectionId, {
    int? yearId,
    int? classId,
    bool? active,
    CancelToken? cancelToken,
  });
  Future<ClassCounselorAssignmentModel> createClassCounselorAssignment(
    int clubId,
    int sectionId, {
    required String userId,
    required int classId,
    int? ecclesiasticalYearId,
    String? responsibilityType,
    bool? exceptional,
    String? exceptionReason,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<ClassCounselorAssignmentModel> updateClassCounselorAssignment(
    String assignmentId, {
    String? responsibilityType,
    bool? exceptional,
    String? exceptionReason,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<ClassCounselorAssignmentModel> revokeClassCounselorAssignment(
    String assignmentId,
  );

  // ── Inscripción en clases anteriores ─────────────────────────────────────

  /// Inscribe al usuario en una clase para el año eclesiástico dado.
  Future<void> enrollUser(String userId, int classId, int yearId);

  // ── Nuevas operaciones para flujo de evidencias ────────────────────────────

  /// Obtiene la clase con progreso detallado (modulos + requerimientos + evidencias).
  Future<ClassWithProgressModel> getClassWithProgress(
      String userId, int classId,
      {int? enrollmentId, CancelToken? cancelToken});

  /// Envia un requerimiento a validacion.
  Future<void> submitRequirement(String userId, int classId, int requirementId,
      {int? enrollmentId});

  /// Sube un archivo de evidencia a un requerimiento.
  Future<RequirementEvidenceModel> uploadRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String filePath,
    required String fileName,
    required String mimeType,
    int? enrollmentId,
    void Function(double)? onProgress,
  });

  /// Elimina un archivo de evidencia de un requerimiento.
  Future<void> deleteRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String fileId,
    int? enrollmentId,
  });
}

/// Implementacion de la fuente de datos remota de clases progresivas.
///
/// Utiliza Dio para llamadas REST al backend SACDIA.
/// Auth token es inyectado automáticamente por [AuthInterceptor].
class ClassesRemoteDataSourceImpl implements ClassesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'ClassesDS';

  ClassesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
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
        return (data['message'] ?? e.message ?? tr('common.error_network'))
            .toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? tr('common.error_network');
  }

  /// Extrae el código de error de negocio (`code`) del cuerpo de la
  /// respuesta, cuando el backend lo incluye junto al `message` genérico.
  String? _extractDioCode(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['code']?.toString();
    } catch (e) {
      AppLogger.w('Error al parsear código de error', tag: _tag, error: e);
    }
    return null;
  }

  Map<String, dynamic>? _enrollmentQuery(int? enrollmentId) =>
      enrollmentId == null ? null : {'enrollmentId': enrollmentId};

  Map<String, dynamic>? _yearQuery(int? yearId) =>
      yearId == null ? null : {'yearId': yearId};

  Map<String, dynamic>? _classIdQuery(int? classId) =>
      classId == null ? null : {'classId': classId};

  Map<String, dynamic>? _activeQuery(bool? active) =>
      active == null ? null : {'active': active};

  Map<String, dynamic> _mergeQueryMaps(List<Map<String, dynamic>?> maps) {
    final result = <String, dynamic>{};
    for (final map in maps) {
      if (map != null) {
        result.addAll(map);
      }
    }
    return result;
  }

  // ── POST /users/:userId/classes/enroll ──────────────────────────────────────

  @override
  Future<void> enrollUser(String userId, int classId, int yearId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/classes/enroll',
        data: {
          'class_id': classId,
          'ecclesiastical_year_id': yearId,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: tr('classes.errors.enroll'),
        code: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      final statusCode = e.response?.statusCode;
      if (statusCode == 403 &&
          _extractDioCode(e) == 'CLASS_PREREQUISITE_NOT_MET') {
        throw ServerException(
          message: tr('classes.errors.prerequisite_not_met'),
          code: statusCode,
        );
      }
      AppLogger.e('Error en enrollUser', tag: _tag, error: e);
      _rethrow(e);
    } catch (e) {
      AppLogger.e('Error en enrollUser', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /classes ────────────────────────────────────────────────────────────

  @override
  Future<List<ClassModel>> getClasses(
      {int? clubTypeId, CancelToken? cancelToken}) async {
    try {
      final queryParams = clubTypeId != null ? '?clubTypeId=$clubTypeId' : '';

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.classes}$queryParams',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        // El endpoint GET /classes retorna un resultado paginado: { data: [...], meta: {...} }
        // Soportamos también respuesta plana (List) por retrocompatibilidad.
        final List<dynamic> items = body is Map
            ? (body['data'] as List<dynamic>? ?? [])
            : (body as List<dynamic>);
        return items
            .map((json) => ClassModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: tr('classes.errors.fetch_list'), code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClasses', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /classes/:classId ───────────────────────────────────────────────────

  @override
  Future<ClassModel> getClassById(int classId,
      {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.classes}/$classId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: tr('classes.errors.fetch_one'), code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClassById', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /classes/:classId/modules ───────────────────────────────────────────

  @override
  Future<List<ClassModuleModel>> getClassModules(int classId,
      {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.classes}/$classId/modules',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                ClassModuleModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: tr('classes.errors.fetch_modules'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClassModules', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /classes/:classId/honors ────────────────────────────────────────────

  @override
  Future<List<ClassHonorModel>> getClassHonors(int classId,
      {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.classes}/$classId/honors',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                ClassHonorModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: tr('classes.errors.fetch_honors'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClassHonors', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /users/:userId/classes ──────────────────────────────────────────────

  @override
  Future<List<ClassModel>> getUserClasses(String userId,
      {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/classes',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((enrollment) {
          final e = enrollment as Map<String, dynamic>;
          // El backend retorna inscripciones:
          // [{ enrollment_id, investiture_status, overall_progress, classes: {...} }]
          // Mezclamos los campos de enrollment sobre el JSON de clase para que
          // ClassModel.fromJson los reciba en un único mapa plano.
          final classJson = Map<String, dynamic>.from(
              (e['classes'] as Map<String, dynamic>?) ?? e);
          if (e.containsKey('investiture_status')) {
            classJson['investiture_status'] = e['investiture_status'];
          }
          if (e.containsKey('overall_progress')) {
            classJson['overall_progress'] = e['overall_progress'];
          }
          if (e.containsKey('enrollment_id')) {
            classJson['enrollment_id'] = e['enrollment_id'];
          }
          if (e.containsKey('enrollment_date')) {
            classJson['enrollment_date'] = e['enrollment_date'];
          }
          if (e.containsKey('submitted_at')) {
            classJson['submitted_at'] = e['submitted_at'];
          }
          if (e.containsKey('validated_at')) {
            classJson['validated_at'] = e['validated_at'];
          }
          if (e.containsKey('ecclesiastical_year')) {
            classJson['ecclesiastical_year'] = e['ecclesiastical_year'];
          }
          return ClassModel.fromJson(classJson);
        }).toList();
      }

      throw ServerException(
          message: tr('classes.errors.fetch_user_classes'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getUserClasses', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /users/:userId/classes/:classId/progress ────────────────────────────

  @override
  Future<ClassProgressModel> getUserClassProgress(String userId, int classId,
      {int? enrollmentId, CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/classes/$classId/progress',
        queryParameters: _enrollmentQuery(enrollmentId),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassProgressModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: tr('classes.errors.fetch_progress'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getUserClassProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH /users/:userId/classes/:classId/progress ──────────────────────────

  @override
  Future<ClassProgressModel> updateUserClassProgress(
      String userId, int classId, Map<String, dynamic> progressData,
      {int? enrollmentId}) async {
    try {
      final payload = Map<String, dynamic>.from(progressData);
      if (enrollmentId != null) {
        payload['enrollment_id'] = enrollmentId;
      }

      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.users}/$userId/classes/$classId/progress',
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassProgressModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
          message: tr('classes.errors.update_progress'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en updateUserClassProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/sections/:sectionId/classes/progress-scope ──────────

  @override
  Future<ProgressScopeResultModel> getProgressScope(
    int clubId,
    int sectionId, {
    int? yearId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/classes/progress-scope',
        queryParameters: _yearQuery(yearId),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ProgressScopeResultModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: tr('classes.errors.fetch_list'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getProgressScope', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/sections/:sectionId/classes/:classId/members-progress

  @override
  Future<ClassMembersProgressResultModel> getClassMembersProgress(
    int clubId,
    int sectionId,
    int classId, {
    int? yearId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/classes/$classId/members-progress',
        queryParameters: _yearQuery(yearId),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassMembersProgressResultModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: tr('classes.errors.fetch_progress'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getClassMembersProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/sections/:sectionId/class-counselor-assignments ────

  @override
  Future<List<ClassCounselorAssignmentModel>> getClassCounselorAssignments(
    int clubId,
    int sectionId, {
    int? yearId,
    int? classId,
    bool? active,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/class-counselor-assignments',
        queryParameters: _mergeQueryMaps([
          _yearQuery(yearId),
          _classIdQuery(classId),
          _activeQuery(active),
        ]),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map(
              (json) => ClassCounselorAssignmentModel.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      throw ServerException(
        message: tr('classes.errors.fetch_list'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getClassCounselorAssignments', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /clubs/:clubId/sections/:sectionId/class-counselor-assignments ────

  @override
  Future<ClassCounselorAssignmentModel> createClassCounselorAssignment(
    int clubId,
    int sectionId, {
    required String userId,
    required int classId,
    int? ecclesiasticalYearId,
    String? responsibilityType,
    bool? exceptional,
    String? exceptionReason,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final payload = <String, dynamic>{
        'user_id': userId,
        'class_id': classId,
      };
      if (ecclesiasticalYearId != null) {
        payload['ecclesiastical_year_id'] = ecclesiasticalYearId;
      }
      if (responsibilityType != null) {
        payload['responsibility_type'] = responsibilityType;
      }
      if (exceptional != null) {
        payload['exceptional'] = exceptional;
      }
      if (exceptionReason != null) {
        payload['exception_reason'] = exceptionReason;
      }
      if (startDate != null) {
        payload['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        payload['end_date'] = endDate.toIso8601String();
      }

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/class-counselor-assignments',
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassCounselorAssignmentModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: tr('classes.errors.fetch_list'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en createClassCounselorAssignment',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH /class-counselor-assignments/:assignmentId ───────────────────────

  @override
  Future<ClassCounselorAssignmentModel> updateClassCounselorAssignment(
    String assignmentId, {
    String? responsibilityType,
    bool? exceptional,
    String? exceptionReason,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (responsibilityType != null) {
        payload['responsibility_type'] = responsibilityType;
      }
      if (exceptional != null) {
        payload['exceptional'] = exceptional;
      }
      if (exceptionReason != null) {
        payload['exception_reason'] = exceptionReason;
      }
      if (startDate != null) {
        payload['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        payload['end_date'] = endDate.toIso8601String();
      }

      final response = await _dio.patch(
        '$_baseUrl/class-counselor-assignments/$assignmentId',
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassCounselorAssignmentModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: tr('classes.errors.fetch_list'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en updateClassCounselorAssignment',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /class-counselor-assignments/:assignmentId ─────────────────────

  @override
  Future<ClassCounselorAssignmentModel> revokeClassCounselorAssignment(
    String assignmentId,
  ) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl/class-counselor-assignments/$assignmentId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClassCounselorAssignmentModel.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw ServerException(
        message: tr('classes.errors.fetch_list'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en revokeClassCounselorAssignment',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /users/:userId/classes/:classId/progress (detallado) ───────────────
  //
  // El endpoint GET /users/:userId/classes/:classId/progress devuelve el
  // progreso con modulos y secciones. El backend puede variar; construimos
  // la respuesta combinando clase + modulos + progreso por seccion.
  //
  // Si el backend no retorna el detalle completo en un solo endpoint,
  // combinamos las llamadas necesarias.

  @override
  Future<ClassWithProgressModel> getClassWithProgress(
      String userId, int classId,
      {int? enrollmentId, CancelToken? cancelToken}) async {
    try {
      // Intentar obtener progreso detallado en un solo endpoint
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/classes/$classId/progress',
        queryParameters: _enrollmentQuery(enrollmentId),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;

        // Si el backend retorna los modulos embebidos, usar directamente
        if (body.containsKey('modules')) {
          return ClassWithProgressModel.fromJson(body);
        }

        // Si no, obtener la clase y los modulos por separado y combinar
        final classResponse = await _dio.get(
          '$_baseUrl${ApiEndpoints.classes}/$classId',
          cancelToken: cancelToken,
        );

        final modulesResponse = await _dio.get(
          '$_baseUrl${ApiEndpoints.classes}/$classId/modules',
          cancelToken: cancelToken,
        );

        if (classResponse.statusCode == 200 &&
            modulesResponse.statusCode == 200) {
          final classJson = classResponse.data as Map<String, dynamic>;
          final modulesJson = modulesResponse.data as List<dynamic>;

          // Construir JSON combinado
          final combined = {
            ...classJson,
            ...body,
            'modules': modulesJson,
          };

          return ClassWithProgressModel.fromJson(combined);
        }
      }

      throw ServerException(
          message: tr('classes.errors.fetch_with_progress'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getClassWithProgress', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /users/:userId/classes/:classId/sections/:sectionId/submit ─────────

  @override
  Future<void> submitRequirement(String userId, int classId, int requirementId,
      {int? enrollmentId}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/classes/$classId/sections/$requirementId/submit',
        queryParameters: _enrollmentQuery(enrollmentId),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
          message: tr('classes.errors.submit_requirement'),
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en submitRequirement', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /users/:userId/classes/:classId/sections/:sectionId/files ──────────

  @override
  Future<RequirementEvidenceModel> uploadRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String filePath,
    required String fileName,
    required String mimeType,
    int? enrollmentId,
    void Function(double)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/classes/$classId/sections/$requirementId/files',
        queryParameters: _enrollmentQuery(enrollmentId),
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final fraction = sent / total;
            onProgress?.call(fraction);
            AppLogger.d(
              'Upload progress: ${(fraction * 100).toStringAsFixed(1)}%',
              tag: _tag,
            );
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final fileJson = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return RequirementEvidenceModel.fromJson(fileJson);
      }

      throw ServerException(
        message: tr('classes.errors.upload_file'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en uploadRequirementFile', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /users/:userId/classes/:classId/sections/:sectionId/files/:fileId

  @override
  Future<void> deleteRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String fileId,
    int? enrollmentId,
  }) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.users}/$userId/classes/$classId/sections/$requirementId/files/$fileId',
        queryParameters: _enrollmentQuery(enrollmentId),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: tr('classes.errors.delete_file'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en deleteRequirementFile', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
