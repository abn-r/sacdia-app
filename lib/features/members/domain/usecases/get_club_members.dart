import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/club_member.dart';
import '../repositories/members_repository.dart';

/// Parámetros para obtener miembros del club
class GetClubMembersParams extends Equatable {
  final int clubId;
  final int sectionId;

  const GetClubMembersParams({
    required this.clubId,
    required this.sectionId,
  });

  @override
  List<Object> get props => [clubId, sectionId];
}

/// Caso de uso para obtener la lista de miembros del club
class GetClubMembers implements UseCase<List<ClubMember>, GetClubMembersParams> {
  final MembersRepository repository;

  GetClubMembers(this.repository);

  @override
  Future<Either<Failure, List<ClubMember>>> call(
      GetClubMembersParams params) async {
    return await repository.getClubMembers(
      clubId: params.clubId,
      sectionId: params.sectionId,
    );
  }
}
