import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/teen_supervision.dart';
import '../repositories/teen_repository.dart';

/// `GET /users/me/supervision`.
class GetSupervision implements UseCase<TeenSupervision, NoParams> {
  final TeenRepository repository;

  GetSupervision(this.repository);

  @override
  Future<Either<Failure, TeenSupervision>> call(NoParams params) =>
      repository.getSupervision();
}
