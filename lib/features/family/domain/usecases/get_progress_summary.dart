import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dependent_progress_summary.dart';
import '../repositories/family_repository.dart';

/// `GET /guardianships/me/dependents/:id/summary`.
class GetProgressSummary implements UseCase<DependentProgressSummary, String> {
  final FamilyRepository repository;

  GetProgressSummary(this.repository);

  @override
  Future<Either<Failure, DependentProgressSummary>> call(String dependentId) =>
      repository.getProgressSummary(dependentId);
}
