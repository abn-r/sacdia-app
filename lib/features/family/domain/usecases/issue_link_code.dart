import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dependent.dart';
import '../repositories/family_repository.dart';

/// `POST /guardianships/me/dependents/:id/link-codes` (segundo tutor, 72 h).
class IssueLinkCode implements UseCase<IssuedLinkCode, String> {
  final FamilyRepository repository;

  IssueLinkCode(this.repository);

  @override
  Future<Either<Failure, IssuedLinkCode>> call(String dependentId) =>
      repository.issueLinkCode(dependentId);
}
