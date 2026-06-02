import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/class_with_progress.dart';
import '../repositories/classes_repository.dart';

class GetClassWithProgressParams extends Equatable {
  final String userId;
  final int classId;
  final int? enrollmentId;

  const GetClassWithProgressParams({
    required this.userId,
    required this.classId,
    this.enrollmentId,
  });

  @override
  List<Object?> get props => [userId, classId, enrollmentId];
}

/// Caso de uso: obtiene la clase con progreso detallado por modulos/requerimientos.
class GetClassWithProgress
    implements UseCase<ClassWithProgress, GetClassWithProgressParams> {
  final ClassesRepository _repository;

  GetClassWithProgress(this._repository);

  @override
  Future<Either<Failure, ClassWithProgress>> call(
      GetClassWithProgressParams params,
      {CancelToken? cancelToken}) async {
    return _repository.getClassWithProgress(params.userId, params.classId,
        enrollmentId: params.enrollmentId, cancelToken: cancelToken);
  }
}
