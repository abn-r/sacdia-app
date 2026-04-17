import 'package:equatable/equatable.dart';

/// Estado de una asignación de rol
enum AssignmentStatus { pending, active, revoked }

extension AssignmentStatusX on AssignmentStatus {
  String get label {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Pendiente';
      case AssignmentStatus.active:
        return 'Activa';
      case AssignmentStatus.revoked:
        return 'Revocada';
    }
  }
}

/// Entidad de asignación de rol
class RoleAssignment extends Equatable {
  final int id;
  final int clubSectionId;
  final String userId;
  final int roleId;
  final String? roleName;
  final String? clubName;
  final String? sectionName;
  final String status;
  final DateTime? assignedAt;
  final DateTime? revokedAt;
  final String? notes;

  const RoleAssignment({
    required this.id,
    required this.clubSectionId,
    required this.userId,
    required this.roleId,
    this.roleName,
    this.clubName,
    this.sectionName,
    required this.status,
    this.assignedAt,
    this.revokedAt,
    this.notes,
  });

  AssignmentStatus get assignmentStatus {
    switch (status) {
      case 'active':
        return AssignmentStatus.active;
      case 'revoked':
        return AssignmentStatus.revoked;
      default:
        return AssignmentStatus.pending;
    }
  }

  @override
  List<Object?> get props => [
        id,
        clubSectionId,
        userId,
        roleId,
        roleName,
        clubName,
        sectionName,
        status,
        assignedAt,
        revokedAt,
        notes,
      ];
}
