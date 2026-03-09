import 'package:equatable/equatable.dart';

/// Estado de una solicitud de ingreso al club
enum JoinRequestStatus {
  pending,
  approved,
  rejected,
}

/// Extensión para obtener el label en español
extension JoinRequestStatusLabel on JoinRequestStatus {
  String get label {
    switch (this) {
      case JoinRequestStatus.pending:
        return 'Pendiente';
      case JoinRequestStatus.approved:
        return 'Aprobado';
      case JoinRequestStatus.rejected:
        return 'Rechazado';
    }
  }
}

/// Entidad que representa una solicitud de ingreso al club
class JoinRequest extends Equatable {
  final String assignmentId;
  final String userId;
  final String name;
  final String? paternalSurname;
  final String? maternalSurname;
  final String? avatar;
  final String? email;
  final JoinRequestStatus status;
  final DateTime? requestedAt;
  final DateTime? resolvedAt;

  const JoinRequest({
    required this.assignmentId,
    required this.userId,
    required this.name,
    this.paternalSurname,
    this.maternalSurname,
    this.avatar,
    this.email,
    required this.status,
    this.requestedAt,
    this.resolvedAt,
  });

  /// Nombre completo del solicitante
  String get fullName {
    final parts = [name, paternalSurname, maternalSurname]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  /// Iniciales para avatar fallback
  String get initials {
    final first = name.isNotEmpty ? name[0].toUpperCase() : '';
    final last = paternalSurname?.isNotEmpty == true
        ? paternalSurname![0].toUpperCase()
        : '';
    return '$first$last';
  }

  @override
  List<Object?> get props => [
        assignmentId,
        userId,
        name,
        paternalSurname,
        maternalSurname,
        avatar,
        email,
        status,
        requestedAt,
        resolvedAt,
      ];
}
