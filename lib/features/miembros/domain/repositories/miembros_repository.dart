import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/club_member.dart';
import '../entities/join_request.dart';

/// Interfaz del repositorio de miembros
abstract class MiembrosRepository {
  /// Obtiene la lista de miembros de una instancia del club
  Future<Either<Failure, List<ClubMember>>> getClubMembers({
    required int clubId,
    required String instanceType,
    required int instanceId,
  });

  /// Obtiene el detalle de un miembro específico del club
  Future<Either<Failure, ClubMember>> getMemberDetail(String userId);

  /// Obtiene la lista de solicitudes de ingreso al club
  Future<Either<Failure, List<JoinRequest>>> getJoinRequests({
    required int clubId,
    required String instanceType,
    required int instanceId,
  });

  /// Aprueba una solicitud de ingreso
  Future<Either<Failure, JoinRequest>> approveJoinRequest(String assignmentId);

  /// Rechaza una solicitud de ingreso
  Future<Either<Failure, JoinRequest>> rejectJoinRequest(String assignmentId);

  /// Asigna un rol de club a un miembro
  Future<Either<Failure, bool>> assignClubRole({
    required int clubId,
    required String instanceType,
    required int instanceId,
    required String userId,
    required String role,
  });

  /// Remueve un rol de club de un miembro
  Future<Either<Failure, bool>> removeClubRole(String assignmentId);
}
