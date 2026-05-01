import 'package:easy_localization/easy_localization.dart';

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

  /// Etiqueta localizada para mostrar al usuario.
  String get label {
    switch (this) {
      case InvestitureStatus.inProgress:
        return tr('investiture.status.in_progress');
      case InvestitureStatus.submittedForValidation:
        return tr('investiture.status.submitted');
      case InvestitureStatus.clubApproved:
        return tr('investiture.status.club_approved');
      case InvestitureStatus.coordinatorApproved:
        return tr('investiture.status.coordinator_approved');
      case InvestitureStatus.fieldApproved:
        return tr('investiture.status.field_approved');
      case InvestitureStatus.approved:
        return tr('investiture.status.approved');
      case InvestitureStatus.rejected:
        return tr('investiture.status.rejected');
      case InvestitureStatus.investido:
        return tr('investiture.status.investido');
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
