import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/members_repository.dart';

/// Parámetros para asignar un rol de club
class AssignClubRoleParams extends Equatable {
  final int clubId;
  final int sectionId;
  final String userId;
  final String role;

  const AssignClubRoleParams({
    required this.clubId,
    required this.sectionId,
    required this.userId,
    required this.role,
  });

  @override
  List<Object> get props =>
      [clubId, sectionId, userId, role];
}

/// Caso de uso para asignar un rol de club a un miembro
class AssignClubRole implements UseCase<bool, AssignClubRoleParams> {
  final MembersRepository repository;

  AssignClubRole(this.repository);

  @override
  Future<Either<Failure, bool>> call(AssignClubRoleParams params) async {
    return await repository.assignClubRole(
      clubId: params.clubId,
      sectionId: params.sectionId,
      userId: params.userId,
      role: params.role,
    );
  }
}
