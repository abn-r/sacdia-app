import 'dart:io';

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/honor.dart';
import '../entities/honor_category.dart';
import '../entities/honor_group.dart';
import '../entities/honor_requirement.dart';
import '../entities/requirement_evidence.dart';
import '../entities/user_honor.dart';
import '../entities/user_honor_requirement_progress.dart';
import '../usecases/register_user_honor.dart';

/// Repositorio de especialidades (interfaz del dominio)
abstract class HonorsRepository {
  /// Obtiene todas las categorías de especialidades
  Future<Either<Failure, List<HonorCategory>>> getHonorCategories(
      {RequestCancelToken? cancelToken});

  /// Obtiene especialidades filtradas
  Future<Either<Failure, List<Honor>>> getHonors({
    int? categoryId,
    int? clubTypeId,
    int? skillLevel,
    RequestCancelToken? cancelToken,
  });

  /// Obtiene el detalle de una especialidad
  Future<Either<Failure, Honor>> getHonorById(int honorId,
      {RequestCancelToken? cancelToken});

  /// Obtiene las especialidades de un usuario
  Future<Either<Failure, List<UserHonor>>> getUserHonors(String userId,
      {RequestCancelToken? cancelToken});

  /// Obtiene estadísticas de especialidades de un usuario
  Future<Either<Failure, Map<String, dynamic>>> getUserHonorStats(String userId,
      {RequestCancelToken? cancelToken});

  /// Inscribe a un usuario en una especialidad
  Future<Either<Failure, UserHonor>> enrollUserInHonor(
      String userId, int honorId);

  /// Actualiza el estado de una especialidad de usuario
  Future<Either<Failure, UserHonor>> updateUserHonor(
    String userId,
    int honorId,
    Map<String, dynamic> data,
  );

  /// Actualiza el modo canónico de trabajo de una especialidad inscrita.
  Future<Either<Failure, UserHonor>> updateHonorCompletionMode({
    required String userId,
    required int honorId,
    required HonorCompletionMode completionMode,
  });

  /// Elimina la inscripción de un usuario en una especialidad
  Future<Either<Failure, void>> deleteUserHonor(String userId, int honorId);

  /// Registra una especialidad completada con datos de evidencia
  Future<Either<Failure, UserHonor>> registerUserHonor(
    RegisterUserHonorParams params,
  );

  /// Obtiene las especialidades agrupadas por categoría
  Future<Either<Failure, List<HonorGroup>>> getHonorsGroupedByCategory(
      {RequestCancelToken? cancelToken});

  /// Obtiene los requisitos del catálogo para una especialidad
  Future<Either<Failure, List<HonorRequirement>>> getHonorRequirements(
      int honorId,
      {RequestCancelToken? cancelToken});

  /// Obtiene el progreso del usuario por requisito para una especialidad inscrita.
  Future<Either<Failure, List<UserHonorRequirementProgress>>>
      getUserHonorProgress(String userId, int honorId,
          {RequestCancelToken? cancelToken});

  /// Actualiza el progreso de un requisito individual.
  Future<Either<Failure, UserHonorRequirementProgress>>
      updateRequirementProgress({
    required String userId,
    required int honorId,
    required int requirementId,
    required bool completed,
    String? notes,
  });

  /// Actualiza el progreso de múltiples requisitos en una sola operación.
  /// [updates] es una lista de mapas con requirementId, completed y notes opcional.
  Future<Either<Failure, List<UserHonorRequirementProgress>>>
      bulkUpdateRequirementProgress(
          String userId, int honorId, List<Map<String, dynamic>> updates);

  /// Sube un archivo de evidencia general al honor del usuario.
  Future<Either<Failure, void>> uploadHonorFile({
    required String userId,
    required int honorId,
    required File file,
    required String fileName,
    HonorFileUploadField uploadField = HonorFileUploadField.images,
  });

  /// Sube un archivo de evidencia para un requisito específico de una especialidad.
  /// [mimeType] debe ser validado por el llamador antes de invocar este método.
  Future<Either<Failure, RequirementEvidence>> uploadRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    File file, {
    required String mimeType,
  });

  /// Agrega un enlace como evidencia de un requisito.
  Future<Either<Failure, RequirementEvidence>> addRequirementEvidenceLink(
    String userId,
    int honorId,
    int requirementId,
    String url,
  );

  /// Obtiene todas las evidencias de un requisito de especialidad.
  Future<Either<Failure, List<RequirementEvidence>>> getRequirementEvidences(
    String userId,
    int honorId,
    int requirementId, {
    RequestCancelToken? cancelToken,
  });

  /// Elimina una evidencia de un requisito de especialidad.
  Future<Either<Failure, void>> deleteRequirementEvidence(
    String userId,
    int honorId,
    int requirementId,
    int evidenceId,
  );
}
