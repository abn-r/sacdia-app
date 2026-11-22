import 'package:equatable/equatable.dart';

/// Estado de una inscripción en una certificación.
///
/// Espejo de los estados del backend (`ENROLLED`, `IN_PROGRESS`,
/// `READY_FOR_CLOSEOUT`, `SUBMITTED_FOR_FINAL_REVIEW`, `APPROVED`,
/// `CERTIFIED`, `CHANGES_REQUESTED`, `WITHDRAWN`, `EXPIRED`).
enum CertificationEnrollmentStatus {
  enrolled,
  inProgress,
  readyForCloseout,
  submittedForFinalReview,
  approved,
  certified,
  changesRequested,
  withdrawn,
  expired,
}

/// Convierte el valor wire del backend al enum. Un valor ausente o
/// desconocido cae en [fallback]: así un servidor anterior al rediseño
/// (sin `status`) sigue mostrando la inscripción como «en curso».
CertificationEnrollmentStatus certificationEnrollmentStatusFromWire(
  String? value, {
  CertificationEnrollmentStatus fallback =
      CertificationEnrollmentStatus.inProgress,
}) {
  switch (value?.toUpperCase()) {
    case 'ENROLLED':
      return CertificationEnrollmentStatus.enrolled;
    case 'IN_PROGRESS':
      return CertificationEnrollmentStatus.inProgress;
    case 'READY_FOR_CLOSEOUT':
      return CertificationEnrollmentStatus.readyForCloseout;
    case 'SUBMITTED_FOR_FINAL_REVIEW':
      return CertificationEnrollmentStatus.submittedForFinalReview;
    case 'APPROVED':
      return CertificationEnrollmentStatus.approved;
    case 'CERTIFIED':
      return CertificationEnrollmentStatus.certified;
    case 'CHANGES_REQUESTED':
      return CertificationEnrollmentStatus.changesRequested;
    case 'WITHDRAWN':
      return CertificationEnrollmentStatus.withdrawn;
    case 'EXPIRED':
      return CertificationEnrollmentStatus.expired;
    default:
      return fallback;
  }
}

extension CertificationEnrollmentStatusX on CertificationEnrollmentStatus {
  /// La certificación ya se otorgó.
  bool get isCertified =>
      this == CertificationEnrollmentStatus.certified ||
      this == CertificationEnrollmentStatus.approved;

  /// El cierre (acta de la junta) ya se puede abrir para enviar o corregir.
  bool get isCloseoutOpen =>
      this == CertificationEnrollmentStatus.readyForCloseout ||
      this == CertificationEnrollmentStatus.changesRequested;

  /// El cierre ya se envió y espera la revisión final.
  bool get isUnderFinalReview =>
      this == CertificationEnrollmentStatus.submittedForFinalReview;

  /// Una inscripción retirada ya no cuenta: la certificación vuelve a estar
  /// disponible.
  bool get isEnrolled => this != CertificationEnrollmentStatus.withdrawn;

  /// Los requisitos ya no se pueden enviar ni corregir.
  bool get isClosed =>
      isCertified ||
      this == CertificationEnrollmentStatus.expired ||
      this == CertificationEnrollmentStatus.withdrawn;
}

/// Conteo de requisitos de una inscripción por estado.
///
/// Espejo de `summary` en `GET .../certifications` y `.../progress`.
class CertificationSummary extends Equatable {
  final int total;
  final int approved;
  final int submitted;
  final int changesRequested;
  final int notStartedOrDraft;

  const CertificationSummary({
    this.total = 0,
    this.approved = 0,
    this.submitted = 0,
    this.changesRequested = 0,
    this.notStartedOrDraft = 0,
  });

  @override
  List<Object?> get props =>
      [total, approved, submitted, changesRequested, notStartedOrDraft];
}
