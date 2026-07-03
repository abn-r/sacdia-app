import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../../core/models/paginated_result.dart';
import '../entities/camporee.dart';
import '../entities/camporee_event.dart';
import '../entities/camporee_judge_assignment.dart';
import '../entities/camporee_member.dart';
import '../entities/camporee_payment.dart';
import '../entities/camporee_rubric.dart';
import '../entities/camporee_score_submission.dart';

/// Repositorio de camporees (interfaz del dominio)
abstract class CamporeesRepository {
  /// Obtiene la lista de camporees. Opcionalmente filtra por activos.
  Future<Either<Failure, List<Camporee>>> getCamporees(
      {bool? active, RequestCancelToken? cancelToken});

  /// Obtiene el detalle de un camporee por ID.
  Future<Either<Failure, Camporee>> getCamporeeDetail(int camporeeId,
      {RequestCancelToken? cancelToken});

  /// Obtiene eventos registrados de un camporee.
  Future<Either<Failure, List<CamporeeEvent>>> getCamporeeEvents(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  });

  /// Registra un miembro en un camporee.
  Future<Either<Failure, CamporeeMember>> registerMember(
    int camporeeId, {
    required String userId,
    String? camporeeType,
    String? clubName,
    int? insuranceId,
  });

  /// Obtiene los miembros inscritos en un camporee (respuesta paginada).
  Future<Either<Failure, PaginatedResult<CamporeeMember>>> getCamporeeMembers(
    int camporeeId, {
    int page = 1,
    int limit = 50,
    String? status,
    RequestCancelToken? cancelToken,
  });

  /// Remueve un miembro de un camporee.
  Future<Either<Failure, void>> removeMember(int camporeeId, String userId);

  // ── Payments ────────────────────────────────────────────────────────────────

  /// Inscribe un club en un camporee.
  Future<Either<Failure, CamporeeEnrolledClub>> enrollClub(
    int camporeeId, {
    required int clubSectionId,
  });

  /// Obtiene los clubes inscritos en un camporee.
  Future<Either<Failure, List<CamporeeEnrolledClub>>> getEnrolledClubs(
      int camporeeId,
      {RequestCancelToken? cancelToken});

  /// Crea un pago para un miembro en un camporee.
  Future<Either<Failure, CamporeePayment>> createPayment(
    int camporeeId,
    String memberId, {
    required double amount,
    required String paymentType,
    String? reference,
    DateTime? paymentDate,
    String? notes,
  });

  /// Obtiene los pagos de un miembro en un camporee.
  Future<Either<Failure, List<CamporeePayment>>> getMemberPayments(
    int camporeeId,
    String memberId, {
    RequestCancelToken? cancelToken,
  });

  /// Obtiene todos los pagos de un camporee.
  Future<Either<Failure, List<CamporeePayment>>> getCamporeePayments(
      int camporeeId,
      {RequestCancelToken? cancelToken});

  /// Obtiene asignaciones del juez autenticado para scoring de camporee.
  Future<Either<Failure, List<CamporeeJudgeAssignment>>> getMyJudgeAssignments(
      {RequestCancelToken? cancelToken});

  /// Obtiene rúbricas activas de un evento puntuable.
  Future<Either<Failure, List<CamporeeRubric>>> getCamporeeEventRubrics(
    int eventId, {
    RequestCancelToken? cancelToken,
  });

  /// Envía puntaje oficial por rúbrica.
  Future<Either<Failure, void>> submitCamporeeEventScore(
    int eventId,
    int clubSectionId, {
    required CamporeeScoreSubmission submission,
  });
}
