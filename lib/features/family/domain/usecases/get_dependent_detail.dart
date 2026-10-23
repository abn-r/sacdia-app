import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dependent.dart';
import '../repositories/family_repository.dart';

/// `GET /guardianships/me/dependents/:id`.
class GetDependentDetail implements UseCase<DependentDetail, String> {
  final FamilyRepository repository;

  GetDependentDetail(this.repository);

  @override
  Future<Either<Failure, DependentDetail>> call(String dependentId) =>
      repository.getDependent(dependentId);
}
