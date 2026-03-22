import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/unit.dart';
import '../repositories/units_repository.dart';

class UpdateUnitParams extends Equatable {
  final int clubId;
  final int unitId;
  final String? name;
  final String? captainId;
  final String? secretaryId;
  final String? advisorId;
  final String? substituteAdvisorId;
  final int? clubTypeId;
  final int? clubSectionId;
  final bool? active;

  const UpdateUnitParams({
    required this.clubId,
    required this.unitId,
    this.name,
    this.captainId,
    this.secretaryId,
    this.advisorId,
    this.substituteAdvisorId,
    this.clubTypeId,
    this.clubSectionId,
    this.active,
  });

  @override
  List<Object?> get props => [
        clubId,
        unitId,
        name,
        captainId,
        secretaryId,
        advisorId,
        substituteAdvisorId,
        clubTypeId,
        clubSectionId,
        active,
      ];
}

/// Caso de uso: actualiza una unidad existente.
class UpdateUnit {
  final UnitsRepository _repository;

  const UpdateUnit(this._repository);

  Future<Either<Failure, Unit>> call(UpdateUnitParams params) {
    return _repository.updateUnit(
      clubId: params.clubId,
      unitId: params.unitId,
      name: params.name,
      captainId: params.captainId,
      secretaryId: params.secretaryId,
      advisorId: params.advisorId,
      substituteAdvisorId: params.substituteAdvisorId,
      clubTypeId: params.clubTypeId,
      clubSectionId: params.clubSectionId,
      active: params.active,
    );
  }
}
