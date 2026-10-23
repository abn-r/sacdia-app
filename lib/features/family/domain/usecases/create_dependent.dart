import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dependent.dart';
import '../repositories/family_repository.dart';

/// `POST /guardianships/me/dependents` (paso 0: alta del menor).
class CreateDependent
    implements UseCase<DependentSummary, CreateDependentInput> {
  final FamilyRepository repository;

  CreateDependent(this.repository);

  @override
  Future<Either<Failure, DependentSummary>> call(CreateDependentInput params) =>
      repository.createDependent(params);
}
