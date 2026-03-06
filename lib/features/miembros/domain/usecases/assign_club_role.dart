import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/miembros_repository.dart';

/// Parámetros para asignar un rol de club
class AssignClubRoleParams extends Equatable {
  final int clubId;
  final String instanceType;
  final int instanceId;
  final String userId;
  final String role;

  const AssignClubRoleParams({
    required this.clubId,
    required this.instanceType,
    required this.instanceId,
    required this.userId,
    required this.role,
  });

  @override
  List<Object> get props =>
      [clubId, instanceType, instanceId, userId, role];
}

/// Caso de uso para asignar un rol de club a un miembro
class AssignClubRole implements UseCase<bool, AssignClubRoleParams> {
  final MiembrosRepository repository;

  AssignClubRole(this.repository);

  @override
  Future<Either<Failure, bool>> call(AssignClubRoleParams params) async {
    return await repository.assignClubRole(
      clubId: params.clubId,
      instanceType: params.instanceType,
      instanceId: params.instanceId,
      userId: params.userId,
      role: params.role,
    );
  }
}
