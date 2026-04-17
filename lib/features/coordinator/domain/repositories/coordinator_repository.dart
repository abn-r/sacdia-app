import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../entities/sla_dashboard.dart';
import '../entities/evidence_review_item.dart';
import '../entities/camporee_approval.dart';

/// Repositorio del módulo de coordinador (interfaz del dominio).
abstract class CoordinatorRepository {
  // ── SLA Dashboard ─────────────────────────────────────────────────────────

  /// Devuelve el dashboard SLA operativo del coordinador.
  /// GET /admin/analytics/sla-dashboard
  Future<Either<Failure, SlaDashboard>> getSlaDashboard({
    CancelToken? cancelToken,
  });

  // ── Evidence Review ───────────────────────────────────────────────────────

  /// Devuelve la lista paginada de evidencias pendientes de revisión.
  /// GET /evidence-review/pending?page=1&limit=20&type=folder|class|honor
  Future<Either<Failure, List<EvidenceReviewItem>>> getPendingEvidence({
    int page = 1,
    int limit = 20,
    EvidenceReviewType? type,
    CancelToken? cancelToken,
  });

  /// Devuelve el detalle de una evidencia con archivos e historial.
  /// GET /evidence-review/:type/:id
  Future<Either<Failure, EvidenceReviewItem>> getEvidenceDetail({
    required EvidenceReviewType type,
    required String id,
    CancelToken? cancelToken,
  });

  /// Aprueba una evidencia con comentario opcional.
  /// POST /evidence-review/:type/:id/approve
  Future<Either<Failure, void>> approveEvidence({
    required EvidenceReviewType type,
    required String id,
    String? comment,
  });

  /// Rechaza una evidencia. [rejectionReason] es requerido.
  /// POST /evidence-review/:type/:id/reject
  Future<Either<Failure, void>> rejectEvidence({
    required EvidenceReviewType type,
    required String id,
    required String rejectionReason,
  });

  /// Aprueba múltiples evidencias en lote.
  /// POST /evidence-review/bulk-approve
  Future<Either<Failure, void>> bulkApproveEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
  });

  /// Rechaza múltiples evidencias en lote.
  /// POST /evidence-review/bulk-reject
  Future<Either<Failure, void>> bulkRejectEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
    required String rejectionReason,
  });

  // ── Camporee list ─────────────────────────────────────────────────────────

  /// Devuelve la lista de camporees locales activos.
  /// GET /camporees?active=true
  Future<Either<Failure, List<CamporeeItem>>> listLocalCamporees({
    bool activeOnly = true,
    CancelToken? cancelToken,
  });

  /// Devuelve la lista de camporees de unión activos.
  /// GET /camporees/union
  Future<Either<Failure, List<CamporeeItem>>> listUnionCamporees({
    CancelToken? cancelToken,
  });

  // ── Camporee pending approvals ────────────────────────────────────────────

  /// Devuelve las inscripciones pendientes de aprobación para un camporee local.
  /// GET /camporees/:camporeeId/pending
  Future<Either<Failure, CamporeePendingApprovals>> getLocalCamporeePending(
    int camporeeId, {
    CancelToken? cancelToken,
  });

  /// Devuelve las inscripciones pendientes de aprobación para un camporee de unión.
  /// GET /camporees/union/:camporeeId/pending
  Future<Either<Failure, CamporeePendingApprovals>> getUnionCamporeePending(
    int camporeeId, {
    CancelToken? cancelToken,
  });

  // ── Club enrollment approve/reject ────────────────────────────────────────

  /// Aprueba la inscripción tardía de un club.
  /// PATCH /camporees/:camporeeId/clubs/:camporeeClubId/approve
  Future<Either<Failure, void>> approveCamporeeClub({
    required int camporeeId,
    required int camporeeClubId,
    required CamporeeScope scope,
  });

  /// Rechaza la inscripción tardía de un club.
  /// PATCH /camporees/:camporeeId/clubs/:camporeeClubId/reject
  Future<Either<Failure, void>> rejectCamporeeClub({
    required int camporeeId,
    required int camporeeClubId,
    required CamporeeScope scope,
    String? rejectionReason,
  });

  // ── Member enrollment approve/reject ──────────────────────────────────────

  /// Aprueba la inscripción tardía de un miembro.
  /// PATCH /camporees/:camporeeId/members/:camporeeMemberId/approve
  Future<Either<Failure, void>> approveCamporeeMember({
    required int camporeeId,
    required int camporeeMemberId,
    required CamporeeScope scope,
  });

  /// Rechaza la inscripción tardía de un miembro.
  /// PATCH /camporees/:camporeeId/members/:camporeeMemberId/reject
  Future<Either<Failure, void>> rejectCamporeeMember({
    required int camporeeId,
    required int camporeeMemberId,
    required CamporeeScope scope,
    String? rejectionReason,
  });

  // ── Payment approve/reject ────────────────────────────────────────────────

  /// Aprueba un pago tardío.
  /// PATCH /camporees/payments/:camporeePaymentId/approve
  /// (no lleva camporeeId en la ruta — es independiente del scope)
  Future<Either<Failure, void>> approveCamporeePayment({
    required String camporeePaymentId,
  });

  /// Rechaza un pago tardío.
  /// PATCH /camporees/payments/:camporeePaymentId/reject
  Future<Either<Failure, void>> rejectCamporeePayment({
    required String camporeePaymentId,
    String? rejectionReason,
  });
}
