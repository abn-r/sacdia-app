import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/units_repository.dart';

class DeleteUnitParams extends Equatable {
  final int clubId;
  final int unitId;

  const DeleteUnitParams({required this.clubId, required this.unitId});

  @override
  List<Object> get props => [clubId, unitId];
}

/// Caso de uso: elimina (soft-delete) una unidad del club.
class DeleteUnit {
  final UnitsRepository _repository;

  const DeleteUnit(this._repository);

  Future<Either<Failure, void>> call(DeleteUnitParams params) {
    return _repository.deleteUnit(
      clubId: params.clubId,
      unitId: params.unitId,
    );
  }
}
