import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/member_insurance.dart';
import '../repositories/seguros_repository.dart';

/// Parámetros para obtener la lista de seguros del club.
class GetMembersInsuranceParams extends Equatable {
  final int clubId;
  final String instanceType;
  final int instanceId;

  const GetMembersInsuranceParams({
    required this.clubId,
    required this.instanceType,
    required this.instanceId,
  });

  @override
  List<Object> get props => [clubId, instanceType, instanceId];
}

/// Caso de uso: obtiene la lista de miembros con estado de seguro.
class GetMembersInsurance {
  final SegurosRepository _repository;

  const GetMembersInsurance(this._repository);

  Future<Either<Failure, List<MemberInsurance>>> call(
      GetMembersInsuranceParams params) {
    return _repository.getMembersInsurance(
      clubId: params.clubId,
      instanceType: params.instanceType,
      instanceId: params.instanceId,
    );
  }
}
