import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/annual_continuation.dart';
import '../entities/club_member.dart';
import '../entities/join_request.dart';

/// Interfaz del repositorio de miembros
abstract class MembersRepository {
  /// Obtiene la lista de miembros de una sección del club
  Future<Either<Failure, List<ClubMember>>> getClubMembers({
    required int clubId,
    required int sectionId,
    RequestCancelToken? cancelToken,
  });

  /// Obtiene el detalle de un miembro específico del club
  Future<Either<Failure, ClubMember>> getMemberDetail(String userId,
      {RequestCancelToken? cancelToken});

  /// Obtiene la lista de solicitudes de ingreso al club
  Future<Either<Failure, List<JoinRequest>>> getJoinRequests({
    required int clubId,
    required int sectionId,
    RequestCancelToken? cancelToken,
  });

  /// Aprueba una solicitud de ingreso
  Future<Either<Failure, JoinRequest>> approveJoinRequest(String assignmentId);

  /// Rechaza una solicitud de ingreso
  Future<Either<Failure, JoinRequest>> rejectJoinRequest(String assignmentId);

  /// Asigna un rol de club a un miembro
  Future<Either<Failure, bool>> assignClubRole({
    required int clubId,
    required int sectionId,
    required String userId,
    required String role,
  });

  /// Remueve un rol de club de un miembro
  Future<Either<Failure, bool>> removeClubRole(String assignmentId);

  /// No inscritos del año vigente para la sección destino.
  Future<Either<Failure, List<AnnualContinuation>>> getAnnualContinuations(
      int sectionId);

  /// Inscribe no inscritos. Resultados por usuario.
  Future<Either<Failure, ContinuationBatchResult>> submitAnnualContinuations({
    required int sectionId,
    required List<String> userIds,
  });

  /// Inscribe al usuario owner al año eclesiástico actual.
  Future<Either<Failure, void>> annualEnroll(String userId,
      {int? clubSectionId});
}
