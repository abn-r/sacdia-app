/// Estado de investidura de un enrollment.
///
/// Máquina de estados:
/// IN_PROGRESS → SUBMITTED_FOR_VALIDATION → APPROVED → INVESTIDO
///                                        → REJECTED → (editar) → SUBMITTED_FOR_VALIDATION
enum InvestitureStatus {
  inProgress,
  submittedForValidation,
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
      case InvestitureStatus.approved:
        return 'APPROVED';
      case InvestitureStatus.rejected:
        return 'REJECTED';
      case InvestitureStatus.investido:
        return 'INVESTIDO';
    }
  }
}
