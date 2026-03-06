import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/class_with_progress.dart';
import '../repositories/classes_repository.dart';

class GetClassWithProgressParams extends Equatable {
  final String userId;
  final int classId;

  const GetClassWithProgressParams({
    required this.userId,
    required this.classId,
  });

  @override
  List<Object?> get props => [userId, classId];
}

/// Caso de uso: obtiene la clase con progreso detallado por modulos/requerimientos.
class GetClassWithProgress
    implements UseCase<ClassWithProgress, GetClassWithProgressParams> {
  final ClassesRepository _repository;

  GetClassWithProgress(this._repository);

  @override
  Future<Either<Failure, ClassWithProgress>> call(
      GetClassWithProgressParams params) async {
    return _repository.getClassWithProgress(params.userId, params.classId);
  }
}
