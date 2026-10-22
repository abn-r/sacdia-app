import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/coordinator_club.dart';
import '../entities/coordinator_scope.dart';
import '../entities/sla_dashboard.dart';
import '../entities/evidence_review_item.dart';

/// Repositorio del módulo de coordinador (interfaz del dominio).
abstract class CoordinatorRepository {
  // ── Scope ────────────────────────────────────────────────────────────────

  /// Devuelve el alcance efectivo del coordinador actual.
  /// GET /coordination/me/scope
  Future<Either<Failure, CoordinatorScope>> getMyScope({
    RequestCancelToken? cancelToken,
  });

  // ── Clubs list ────────────────────────────────────────────────────────────

  /// Devuelve la lista de clubs accesibles para el coordinador.
  /// Derivado de /coordination/me/scope, agrupado por club.
  Future<Either<Failure, List<CoordinatorClub>>> listClubs({
    int? localFieldId,
    RequestCancelToken? cancelToken,
  });

  // ── SLA Dashboard ─────────────────────────────────────────────────────────

  /// Devuelve el dashboard SLA operativo del coordinador.
  /// GET /admin/analytics/sla-dashboard
  Future<Either<Failure, SlaDashboard>> getSlaDashboard({
    RequestCancelToken? cancelToken,
  });

  // ── Evidence Review ───────────────────────────────────────────────────────

  /// Devuelve la lista paginada de evidencias pendientes de revisión.
  /// GET /evidence-review/pending?page=1&limit=20&type=class|honor
  Future<Either<Failure, EvidenceReviewPage>> getPendingEvidence({
    int page = 1,
    int limit = kPendingEvidencePageSize,
    EvidenceReviewType? type,
    RequestCancelToken? cancelToken,
  });

  /// Devuelve el detalle de una evidencia con archivos e historial.
  /// GET /evidence-review/:type/:id
  Future<Either<Failure, EvidenceReviewItem>> getEvidenceDetail({
    required EvidenceReviewType type,
    required String id,
    RequestCancelToken? cancelToken,
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
}
