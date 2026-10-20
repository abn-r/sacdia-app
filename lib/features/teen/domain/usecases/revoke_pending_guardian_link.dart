import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/teen_repository.dart';

/// `POST /users/me/guardian-links/:guardianshipId/revoke`.
///
/// Quita un vínculo PENDIENTE que el propio adolescente inició; reinicia el
/// reloj de los 90 días. El servidor responde 404 si el vínculo no existe o ya
/// está verificado.
class RevokePendingGuardianLink implements UseCase<void, String> {
  final TeenRepository repository;

  RevokePendingGuardianLink(this.repository);

  @override
  Future<Either<Failure, void>> call(String guardianshipId) =>
      repository.revokePendingLink(guardianshipId);
}
