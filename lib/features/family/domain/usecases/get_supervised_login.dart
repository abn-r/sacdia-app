import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/supervised_login.dart';
import '../repositories/family_repository.dart';

/// `GET /guardianships/me/dependents/:id/supervised-login`.
class GetSupervisedLogin implements UseCase<SupervisedLoginStatus, String> {
  final FamilyRepository repository;

  GetSupervisedLogin(this.repository);

  @override
  Future<Either<Failure, SupervisedLoginStatus>> call(String dependentId) =>
      repository.getSupervisedLogin(dependentId);
}
