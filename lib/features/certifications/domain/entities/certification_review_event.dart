import 'package:equatable/equatable.dart';

/// Evento del historial de revisión de un requisito de certificación.
///
/// NOTA DE CONTRATO: el backend participante
/// (`GET .../requirements/:sectionId`) solo devuelve la foto más reciente
/// del requisito (`status`, `submitted_at`, `reviewed_at`,
/// `last_review_comment`) — no expone la lista completa de
/// `certification_review_events`. Esa tabla completa solo es visible para
/// revisores vía `GET /certifications/reviews/requirements/:progressId`
/// (permiso `certifications:review`), fuera del alcance de la app de
/// participantes.
///
/// Por eso [CertificationReviewEvent] se construye del lado del cliente a
/// partir de los campos ya disponibles en [CertificationRequirement]
/// (ver `deriveHistory`), en vez de consumir un endpoint de historial
/// dedicado. El resultado es como máximo un evento (el más reciente).
class CertificationReviewEvent extends Equatable {
  final String eventType;
  final String? comment;
  final DateTime? occurredAt;

  const CertificationReviewEvent({
    required this.eventType,
    this.comment,
    this.occurredAt,
  });

  /// Deriva el historial visible para el participante a partir de los
  /// campos de estado del requisito. Devuelve como máximo un evento.
  static List<CertificationReviewEvent> deriveHistory({
    required String status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? lastReviewComment,
  }) {
    if (reviewedAt != null) {
      return [
        CertificationReviewEvent(
          eventType: status == 'CHANGES_REQUESTED'
              ? 'REQUIREMENT_CHANGES_REQUESTED'
              : 'REQUIREMENT_APPROVED',
          comment: lastReviewComment,
          occurredAt: reviewedAt,
        ),
      ];
    }
    if (submittedAt != null) {
      return [
        CertificationReviewEvent(
          eventType: 'REQUIREMENT_SUBMITTED',
          occurredAt: submittedAt,
        ),
      ];
    }
    return const [];
  }

  @override
  List<Object?> get props => [eventType, comment, occurredAt];
}
