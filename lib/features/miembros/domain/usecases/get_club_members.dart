import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/club_member.dart';
import '../repositories/miembros_repository.dart';

/// Parámetros para obtener miembros del club
class GetClubMembersParams extends Equatable {
  final int clubId;
  final String instanceType;
  final int instanceId;

  const GetClubMembersParams({
    required this.clubId,
    required this.instanceType,
    required this.instanceId,
  });

  @override
  List<Object> get props => [clubId, instanceType, instanceId];
}

/// Caso de uso para obtener la lista de miembros del club
class GetClubMembers implements UseCase<List<ClubMember>, GetClubMembersParams> {
  final MiembrosRepository repository;

  GetClubMembers(this.repository);

  @override
  Future<Either<Failure, List<ClubMember>>> call(
      GetClubMembersParams params) async {
    return await repository.getClubMembers(
      clubId: params.clubId,
      instanceType: params.instanceType,
      instanceId: params.instanceId,
    );
  }
}
