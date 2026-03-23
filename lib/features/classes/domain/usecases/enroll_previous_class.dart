import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/classes_repository.dart';

class EnrollPreviousClassParams extends Equatable {
  final String userId;
  final int classId;
  final int ecclesiasticalYearId;

  const EnrollPreviousClassParams({
    required this.userId,
    required this.classId,
    required this.ecclesiasticalYearId,
  });

  @override
  List<Object?> get props => [userId, classId, ecclesiasticalYearId];
}

/// Caso de uso: inscribe al usuario en una clase que completó antes de unirse
/// a la aplicación, usando el año eclesiástico actual o uno pasado.
class EnrollPreviousClass
    implements UseCase<void, EnrollPreviousClassParams> {
  final ClassesRepository _repository;

  EnrollPreviousClass(this._repository);

  @override
  Future<Either<Failure, void>> call(EnrollPreviousClassParams params) {
    return _repository.enrollUser(
      params.userId,
      params.classId,
      params.ecclesiasticalYearId,
    );
  }
}
