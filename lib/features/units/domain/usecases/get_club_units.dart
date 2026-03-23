import 'package:dartz/dartz.dart' hide Unit;
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/unit.dart';
import '../repositories/units_repository.dart';

class GetClubUnitsParams extends Equatable {
  final int clubId;

  const GetClubUnitsParams({required this.clubId});

  @override
  List<Object> get props => [clubId];
}

/// Caso de uso: obtiene todas las unidades activas de un club.
class GetClubUnits {
  final UnitsRepository _repository;

  const GetClubUnits(this._repository);

  Future<Either<Failure, List<Unit>>> call(GetClubUnitsParams params) {
    return _repository.getClubUnits(clubId: params.clubId);
  }
}
