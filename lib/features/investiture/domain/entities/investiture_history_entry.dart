import 'package:equatable/equatable.dart';
import 'investiture_status.dart';

/// Tipo de acción registrada en el historial de investidura.
enum InvestitureAction {
  submitted,
  approved,
  rejected,
  invested;

  String get label {
    switch (this) {
      case InvestitureAction.submitted:
        return 'Enviado para validación';
      case InvestitureAction.approved:
        return 'Aprobado';
      case InvestitureAction.rejected:
        return 'Rechazado';
      case InvestitureAction.invested:
        return 'Investido';
    }
  }

  static InvestitureAction fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SUBMITTED':
        return InvestitureAction.submitted;
      case 'APPROVED':
        return InvestitureAction.approved;
      case 'REJECTED':
        return InvestitureAction.rejected;
      case 'INVESTED':
      case 'INVESTIDO':
        return InvestitureAction.invested;
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
