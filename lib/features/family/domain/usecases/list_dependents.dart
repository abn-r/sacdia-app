import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dependent.dart';
import '../repositories/family_repository.dart';

/// `GET /guardianships/me/dependents`.
class ListDependents implements UseCase<FamilyOverview, NoParams> {
  final FamilyRepository repository;

  ListDependents(this.repository);

  @override
  Future<Either<Failure, FamilyOverview>> call(NoParams params) =>
      repository.listDependents();
}
