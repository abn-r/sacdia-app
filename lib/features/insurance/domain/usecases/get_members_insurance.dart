import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/member_insurance.dart';
import '../repositories/insurance_repository.dart';

/// Parámetros para obtener la lista de seguros del club.
class GetMembersInsuranceParams extends Equatable {
  final int clubId;
  final int sectionId;

  const GetMembersInsuranceParams({
    required this.clubId,
    required this.sectionId,
  });

  @override
  List<Object> get props => [clubId, sectionId];
}

/// Caso de uso: obtiene la lista de miembros con estado de seguro.
class GetMembersInsurance {
  final InsuranceRepository _repository;

  const GetMembersInsurance(this._repository);

  Future<Either<Failure, List<MemberInsurance>>> call(
      GetMembersInsuranceParams params) {
    return _repository.getMembersInsurance(
      clubId: params.clubId,
      sectionId: params.sectionId,
    );
  }
}
