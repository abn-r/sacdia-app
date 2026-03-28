/// Estado de investidura de un enrollment.
///
/// Máquina de estados:
/// IN_PROGRESS → SUBMITTED_FOR_VALIDATION → CLUB_APPROVED → COORDINATOR_APPROVED → FIELD_APPROVED → APPROVED → INVESTIDO
///                                        → REJECTED → (editar) → SUBMITTED_FOR_VALIDATION
enum InvestitureStatus {
  inProgress,
  submittedForValidation,
  clubApproved,
  coordinatorApproved,
  fieldApproved,
  approved,
  rejected,
  investido;

  /// Etiqueta en español para mostrar al usuario.
  String get label {
    switch (this) {
      case InvestitureStatus.inProgress:
        return 'En progreso';
      case InvestitureStatus.submittedForValidation:
        return 'Enviado';
      case InvestitureStatus.clubApproved:
        return 'Aprobado por el club';
      case InvestitureStatus.coordinatorApproved:
        return 'Aprobado por coordinador';
      case InvestitureStatus.fieldApproved:
        return 'Aprobado por campo';
      case InvestitureStatus.approved:
        return 'Aprobado';
      case InvestitureStatus.rejected:
        return 'Rechazado';
      case InvestitureStatus.investido:
        return 'Investido';
    }
  }

  /// Parsea la cadena que devuelve el backend.
  static InvestitureStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'IN_PROGRESS':
        return InvestitureStatus.inProgress;
      case 'SUBMITTED_FOR_VALIDATION':
        return InvestitureStatus.submittedForValidation;
      case 'CLUB_APPROVED':
        return InvestitureStatus.clubApproved;
      case 'COORDINATOR_APPROVED':
        return InvestitureStatus.coordinatorApproved;
      case 'FIELD_APPROVED':
        return InvestitureStatus.fieldApproved;
      case 'APPROVED':
        return InvestitureStatus.approved;
      case 'REJECTED':
        return InvestitureStatus.rejected;
      case 'INVESTIDO':
        return InvestitureStatus.investido;
      default:
        return InvestitureStatus.inProgress;
    }
  }

  /// Cadena que espera el backend al enviar.
  String get backendValue {
    switch (this) {
      case InvestitureStatus.inProgress:
        return 'IN_PROGRESS';
      case InvestitureStatus.submittedForValidation:
        return 'SUBMITTED_FOR_VALIDATION';
      case InvestitureStatus.clubApproved:
        return 'CLUB_APPROVED';
      case InvestitureStatus.coordinatorApproved:
        return 'COORDINATOR_APPROVED';
      case InvestitureStatus.fieldApproved:
        return 'FIELD_APPROVED';
      case InvestitureStatus.approved:
        return 'APPROVED';
      case InvestitureStatus.rejected:
        return 'REJECTED';
      case InvestitureStatus.investido:
        return 'INVESTIDO';
    }
  }
}
