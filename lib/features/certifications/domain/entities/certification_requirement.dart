import 'package:equatable/equatable.dart';

import 'certification_requirement_component.dart';
import 'certification_review_event.dart';

/// Estados de un requisito (sección) de certificación.
///
/// Espejo de `CERTIFICATION_REQUIREMENT_STATUSES` del backend.
enum CertificationRequirementStatus {
  draft,
  submitted,
  changesRequested,
  approved,
}

CertificationRequirementStatus certificationRequirementStatusFromWire(
  String? value,
) {
  switch (value) {
    case 'SUBMITTED':
      return CertificationRequirementStatus.submitted;
    case 'CHANGES_REQUESTED':
      return CertificationRequirementStatus.changesRequested;
    case 'APPROVED':
      return CertificationRequirementStatus.approved;
    case 'DRAFT':
    default:
      return CertificationRequirementStatus.draft;
  }
}

extension CertificationRequirementStatusWire on CertificationRequirementStatus {
  String get wireValue {
    switch (this) {
      case CertificationRequirementStatus.draft:
        return 'DRAFT';
      case CertificationRequirementStatus.submitted:
        return 'SUBMITTED';
      case CertificationRequirementStatus.changesRequested:
        return 'CHANGES_REQUESTED';
      case CertificationRequirementStatus.approved:
        return 'APPROVED';
    }
  }
}

/// Requisito (sección) de una certificación con sus componentes y estado.
///
/// `sectionId` es el mismo identificador que el backend llama
/// `section_id` / `requirementId` — la app lo usa indistintamente como
/// "requirement id" en rutas y claves de borrador local.
class CertificationRequirement extends Equatable {
  final int sectionId;
  final int moduleId;
  final String name;
  final bool required;
  final CertificationRequirementStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? lastReviewComment;
  final List<CertificationRequirementComponent> components;

  const CertificationRequirement({
    required this.sectionId,
    required this.moduleId,
    required this.name,
    required this.required,
    required this.status,
    this.submittedAt,
    this.reviewedAt,
    this.lastReviewComment,
    this.components = const [],
  });

  /// Solo se puede editar (guardar borrador / adjuntar evidencia) en DRAFT
  /// o CHANGES_REQUESTED — espejo de `assertRequirementEditable` backend.
  bool get canEdit =>
      status == CertificationRequirementStatus.draft ||
      status == CertificationRequirementStatus.changesRequested;

  /// Todos los componentes obligatorios tienen una respuesta completa.
  bool get requiredComponentsComplete =>
      components.where((c) => c.required).every((c) => c.isComplete);

  /// Historial de revisión derivado (ver [CertificationReviewEvent]).
  List<CertificationReviewEvent> get reviewHistory =>
      CertificationReviewEvent.deriveHistory(
        status: status.wireValue,
        submittedAt: submittedAt,
        reviewedAt: reviewedAt,
        lastReviewComment: lastReviewComment,
      );

  @override
  List<Object?> get props => [
        sectionId,
        moduleId,
        name,
        required,
        status,
        submittedAt,
        reviewedAt,
        lastReviewComment,
        components,
      ];
}

/// Resumen de avance de la inscripción — espejo de `ProgressSummary`
/// (backend `certification-definition.types.ts`). Devuelto junto con el
/// requisito actualizado al enviar (`submitRequirement`).
class CertificationProgressSummary extends Equatable {
  final int requiredTotal;
  final int requiredApproved;
  final int optionalTotal;
  final int optionalApproved;
  final int percentComplete;
  final bool allRequiredApproved;

  const CertificationProgressSummary({
    required this.requiredTotal,
    required this.requiredApproved,
    required this.optionalTotal,
    required this.optionalApproved,
    required this.percentComplete,
    required this.allRequiredApproved,
  });

  @override
  List<Object?> get props => [
        requiredTotal,
        requiredApproved,
        optionalTotal,
        optionalApproved,
        percentComplete,
        allRequiredApproved,
      ];
}

/// Resultado de `POST .../requirements/:sectionId/submit`: el requisito
/// actualizado + el resumen de progreso recalculado de la inscripción.
class CertificationRequirementSubmitResult extends Equatable {
  final CertificationRequirement requirement;
  final CertificationProgressSummary progressSummary;

  const CertificationRequirementSubmitResult({
    required this.requirement,
    required this.progressSummary,
  });

  @override
  List<Object?> get props => [requirement, progressSummary];
}
