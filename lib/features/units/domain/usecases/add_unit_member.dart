import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/unit_member.dart';
import '../repositories/units_repository.dart';

class AddUnitMemberParams extends Equatable {
  final int clubId;
  final int unitId;
  final String userId;

  const AddUnitMemberParams({
    required this.clubId,
    required this.unitId,
    required this.userId,
  });

  @override
  List<Object> get props => [clubId, unitId, userId];
}

/// Caso de uso: agrega un miembro a una unidad del club.
class AddUnitMember {
  final UnitsRepository _repository;

  const AddUnitMember(this._repository);

  Future<Either<Failure, UnitMember>> call(AddUnitMemberParams params) {
    return _repository.addUnitMember(
      clubId: params.clubId,
      unitId: params.unitId,
      userId: params.userId,
    );
  }
}
