import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dependent.dart';
import '../repositories/family_repository.dart';

class RevokeGuardianshipParams extends Equatable {
  final String guardianshipId;

  /// `true` cuando el tutor primario quita a un secundario; `false` cuando el
  /// tutor sale por su cuenta.
  final bool removedByPrimary;

  const RevokeGuardianshipParams({
    required this.guardianshipId,
    this.removedByPrimary = false,
  });

  @override
  List<Object?> get props => [guardianshipId, removedByPrimary];
}

/// `POST /guardianships/:id/revoke`.
class RevokeGuardianship
    implements UseCase<RevokeResult, RevokeGuardianshipParams> {
  final FamilyRepository repository;

  RevokeGuardianship(this.repository);

  @override
  Future<Either<Failure, RevokeResult>> call(
    RevokeGuardianshipParams params,
  ) =>
      repository.revoke(
        guardianshipId: params.guardianshipId,
        removedByPrimary: params.removedByPrimary,
      );
}
