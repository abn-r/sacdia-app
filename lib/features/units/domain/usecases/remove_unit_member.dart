import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/units_repository.dart';

class RemoveUnitMemberParams extends Equatable {
  final int clubId;
  final int unitId;
  final int memberId;

  const RemoveUnitMemberParams({
    required this.clubId,
    required this.unitId,
    required this.memberId,
  });

  @override
  List<Object> get props => [clubId, unitId, memberId];
}

/// Caso de uso: remueve un miembro de una unidad del club.
class RemoveUnitMember {
  final UnitsRepository _repository;

  const RemoveUnitMember(this._repository);

  Future<Either<Failure, void>> call(RemoveUnitMemberParams params) {
    return _repository.removeUnitMember(
      clubId: params.clubId,
      unitId: params.unitId,
      memberId: params.memberId,
    );
  }
}
