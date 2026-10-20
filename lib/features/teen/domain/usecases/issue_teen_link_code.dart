import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/teen_supervision.dart';
import '../repositories/teen_repository.dart';

/// `POST /users/me/guardian-link-codes` (72 h; uno nuevo anula el anterior).
class IssueTeenLinkCode implements UseCase<TeenLinkCode, NoParams> {
  final TeenRepository repository;

  IssueTeenLinkCode(this.repository);

  @override
  Future<Either<Failure, TeenLinkCode>> call(NoParams params) =>
      repository.issueLinkCode();
}
