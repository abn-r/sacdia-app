import 'package:dartz/dartz.dart' hide Unit;
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/unit.dart';
import '../repositories/units_repository.dart';

class GetUnitDetailParams extends Equatable {
  final int clubId;
  final int unitId;

  const GetUnitDetailParams({required this.clubId, required this.unitId});

  @override
  List<Object> get props => [clubId, unitId];
}

/// Caso de uso: obtiene el detalle de una unidad con sus miembros activos.
class GetUnitDetail {
  final UnitsRepository _repository;

  const GetUnitDetail(this._repository);

  Future<Either<Failure, Unit>> call(GetUnitDetailParams params) {
    return _repository.getUnitDetail(
      clubId: params.clubId,
      unitId: params.unitId,
    );
  }
}
