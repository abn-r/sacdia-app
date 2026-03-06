import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/join_request.dart';
import '../repositories/miembros_repository.dart';

/// Parámetros para obtener solicitudes de ingreso
class GetJoinRequestsParams extends Equatable {
  final int clubId;
  final String instanceType;
  final int instanceId;

  const GetJoinRequestsParams({
    required this.clubId,
    required this.instanceType,
    required this.instanceId,
  });

  @override
  List<Object> get props => [clubId, instanceType, instanceId];
}

/// Caso de uso para obtener solicitudes de ingreso al club
class GetJoinRequests
    implements UseCase<List<JoinRequest>, GetJoinRequestsParams> {
  final MiembrosRepository repository;

  GetJoinRequests(this.repository);

  @override
  Future<Either<Failure, List<JoinRequest>>> call(
      GetJoinRequestsParams params) async {
    return await repository.getJoinRequests(
      clubId: params.clubId,
      instanceType: params.instanceType,
      instanceId: params.instanceId,
    );
  }
}
