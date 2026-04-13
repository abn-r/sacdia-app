import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../entities/progressive_class.dart';
import '../entities/class_module.dart';
import '../entities/class_progress.dart';
import '../entities/class_with_progress.dart';
import '../entities/requirement_evidence.dart';

/// Repositorio de clases progresivas (interfaz del dominio)
abstract class ClassesRepository {
  /// Obtiene todas las clases progresivas del catalogo.
  Future<Either<Failure, List<ProgressiveClass>>> getClasses({int? clubTypeId, CancelToken? cancelToken});

  /// Obtiene el detalle de una clase especifica.
  Future<Either<Failure, ProgressiveClass>> getClassById(int classId, {CancelToken? cancelToken});

  /// Obtiene los modulos de una clase especifica.
  Future<Either<Failure, List<ClassModule>>> getClassModules(int classId, {CancelToken? cancelToken});

  /// Obtiene las clases de un usuario.
  Future<Either<Failure, List<ProgressiveClass>>> getUserClasses(String userId, {CancelToken? cancelToken});

  /// Obtiene el progreso de una clase de un usuario.
  Future<Either<Failure, ClassProgress>> getUserClassProgress(
      String userId, int classId, {CancelToken? cancelToken});

  /// Actualiza el progreso de una clase de un usuario.
  Future<Either<Failure, ClassProgress>> updateUserClassProgress(
    String userId,
    int classId,
    Map<String, dynamic> progressData,
  );

  // ── Inscripcion en clases anteriores ─────────────────────────────────────

  /// Inscribe al usuario en una clase para el año eclesiastico indicado.
  Future<Either<Failure, void>> enrollUser(
      String userId, int classId, int ecclesiasticalYearId);

  // ── Nuevas operaciones para el flujo de evidencias ────────────────────────

  /// Obtiene la clase con progreso detallado por modulos y requerimientos.
  Future<Either<Failure, ClassWithProgress>> getClassWithProgress(
      String userId, int classId, {CancelToken? cancelToken});

  /// Envia un requerimiento a validacion (pendiente -> enviado).
  Future<Either<Failure, void>> submitRequirement(
      String userId, int classId, int requirementId);

  /// Sube un archivo de evidencia a un requerimiento.
  Future<Either<Failure, RequirementEvidence>> uploadRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String filePath,
    required String fileName,
    required String mimeType,
    void Function(double)? onProgress,
  });

  /// Elimina un archivo de evidencia de un requerimiento.
  Future<Either<Failure, void>> deleteRequirementFile({
    required String userId,
    required int classId,
    required int requirementId,
    required String fileId,
  });
}
