import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/progressive_class.dart';
import '../entities/class_module.dart';
import '../entities/class_progress.dart';

/// Repositorio de clases progresivas (interfaz del dominio)
abstract class ClassesRepository {
  /// Obtiene todas las clases progresivas
  Future<Either<Failure, List<ProgressiveClass>>> getClasses({int? clubTypeId});

  /// Obtiene el detalle de una clase específica
  Future<Either<Failure, ProgressiveClass>> getClassById(int classId);

  /// Obtiene los módulos de una clase específica
  Future<Either<Failure, List<ClassModule>>> getClassModules(int classId);

  /// Obtiene las clases de un usuario
  Future<Either<Failure, List<ProgressiveClass>>> getUserClasses(String userId);

  /// Obtiene el progreso de una clase de un usuario
  Future<Either<Failure, ClassProgress>> getUserClassProgress(String userId, int classId);

  /// Actualiza el progreso de una clase de un usuario
  Future<Either<Failure, ClassProgress>> updateUserClassProgress(
    String userId,
    int classId,
    Map<String, dynamic> progressData,
  );
}
