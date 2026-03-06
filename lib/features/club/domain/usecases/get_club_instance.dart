import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/club_info.dart';
import '../repositories/club_repository.dart';

/// Parámetros para [GetClubInstance].
class GetClubInstanceParams {
  final String clubId;
  final String instanceType;
  final int instanceId;

  const GetClubInstanceParams({
    required this.clubId,
    required this.instanceType,
    required this.instanceId,
  });
}

/// Caso de uso: obtiene los datos de una instancia específica del club.
class GetClubInstance implements UseCase<ClubInstance, GetClubInstanceParams> {
  final ClubRepository _repository;

  const GetClubInstance(this._repository);

  @override
  Future<Either<Failure, ClubInstance>> call(GetClubInstanceParams params) {
    return _repository.getClubInstance(
      clubId: params.clubId,
      instanceType: params.instanceType,
      instanceId: params.instanceId,
    );
  }
}
