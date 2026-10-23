import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dependent.dart';
import '../repositories/family_repository.dart';

/// `GET /guardianships/me/deletion-impact`.
///
/// Es la ÚNICA fuente de cuántos menores hay y qué les pasaría al borrar la
/// cuenta: el cliente no puede apoyarse en `details` de errores (RULING #11528).
class GetDeletionImpact
    implements UseCase<List<DeletionImpactEntry>, NoParams> {
  final FamilyRepository repository;

  GetDeletionImpact(this.repository);

  @override
  Future<Either<Failure, List<DeletionImpactEntry>>> call(NoParams params) =>
      repository.deletionImpact();
}
