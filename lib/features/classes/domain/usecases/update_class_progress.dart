import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/class_progress.dart';
import '../repositories/classes_repository.dart';

/// Caso de uso para actualizar el progreso de una clase
class UpdateClassProgress implements UseCase<ClassProgress, UpdateClassProgressParams> {
  final ClassesRepository repository;

  UpdateClassProgress(this.repository);

  @override
  Future<Either<Failure, ClassProgress>> call(UpdateClassProgressParams params) async {
    return await repository.updateUserClassProgress(
      params.userId,
      params.classId,
      params.progressData,
    );
  }
}

/// Parámetros para actualizar el progreso de una clase
class UpdateClassProgressParams {
  final String userId;
  final int classId;
  final Map<String, dynamic> progressData;

  const UpdateClassProgressParams({
    required this.userId,
    required this.classId,
    required this.progressData,
  });
}
