import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'investiture_status.dart';

/// Tipo de acción registrada en el historial de investidura.
enum InvestitureAction {
  submitted,
  clubApproved,
  coordinatorApproved,
  fieldApproved,
  approved,
  rejected,
  invested,
  expired,
  reinvestitureRequested;

  String get label {
    switch (this) {
      case InvestitureAction.submitted:
        return tr('investiture.history.action_submitted');
      case InvestitureAction.clubApproved:
        return tr('investiture.history.action_club_approved');
      case InvestitureAction.coordinatorApproved:
        return tr('investiture.history.action_coordinator_approved');
      case InvestitureAction.fieldApproved:
        return tr('investiture.history.action_field_approved');
      case InvestitureAction.approved:
        return tr('investiture.history.action_approved');
      case InvestitureAction.rejected:
        return tr('investiture.history.action_rejected');
      case InvestitureAction.invested:
        return tr('investiture.history.action_invested');
      case InvestitureAction.expired:
        return tr('investiture.history.action_expired');
      case InvestitureAction.reinvestitureRequested:
        return tr('investiture.history.action_reinvestiture_requested');
    }
  }

  static InvestitureAction fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SUBMITTED':
        return InvestitureAction.submitted;
      case 'CLUB_APPROVED':
        return InvestitureAction.clubApproved;
      case 'COORDINATOR_APPROVED':
        return InvestitureAction.coordinatorApproved;
      case 'FIELD_APPROVED':
        return InvestitureAction.fieldApproved;
      case 'APPROVED':
        return InvestitureAction.approved;
      case 'REJECTED':
        return InvestitureAction.rejected;
      case 'INVESTED':
      case 'INVESTIDO':
        return InvestitureAction.invested;
      case 'EXPIRED':
        return InvestitureAction.expired;
      case 'REINVESTITURE_REQUESTED':
        return InvestitureAction.reinvestitureRequested;
      default:
        return InvestitureAction.submitted;
    }
  }
}

/// Entidad que representa una entrada en el historial de validación de investidura.
///
/// Devuelta por GET /api/v1/enrollments/:enrollmentId/investiture-history.
class InvestitureHistoryEntry extends Equatable {
  final int id;
  final InvestitureAction action;
  final InvestitureStatus? resultingStatus;
  final String? comments;
  final DateTime performedAt;

  // Datos del usuario que realizó la acción
  final String performerName;
  final String? performerLastName;
  final String? performerRole;

  const InvestitureHistoryEntry({
    required this.id,
    required this.action,
    this.resultingStatus,
    this.comments,
    required this.performedAt,
    required this.performerName,
    this.performerLastName,
    this.performerRole,
  });

  /// Nombre completo del ejecutor.
  String get performerFullName => performerLastName != null
      ? '$performerName $performerLastName'
      : performerName;

  @override
  List<Object?> get props => [
        id,
        action,
        resultingStatus,
        comments,
        performedAt,
        performerName,
        performerLastName,
        performerRole,
      ];
}
