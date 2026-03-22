import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/unit.dart';
import '../repositories/units_repository.dart';

class CreateUnitParams extends Equatable {
  final int clubId;
  final String name;
  final String captainId;
  final String secretaryId;
  final String advisorId;
  final String? substituteAdvisorId;
  final int clubTypeId;
  final int? clubSectionId;

  const CreateUnitParams({
    required this.clubId,
    required this.name,
    required this.captainId,
    required this.secretaryId,
    required this.advisorId,
    this.substituteAdvisorId,
    required this.clubTypeId,
    this.clubSectionId,
  });

  @override
  List<Object?> get props => [
        clubId,
        name,
        captainId,
        secretaryId,
        advisorId,
        substituteAdvisorId,
        clubTypeId,
        clubSectionId,
      ];
}

/// Caso de uso: crea una nueva unidad en el club.
class CreateUnit {
  final UnitsRepository _repository;

  const CreateUnit(this._repository);

  Future<Either<Failure, Unit>> call(CreateUnitParams params) {
    return _repository.createUnit(
      clubId: params.clubId,
      name: params.name,
      captainId: params.captainId,
      secretaryId: params.secretaryId,
      advisorId: params.advisorId,
      substituteAdvisorId: params.substituteAdvisorId,
      clubTypeId: params.clubTypeId,
      clubSectionId: params.clubSectionId,
    );
  }
}
