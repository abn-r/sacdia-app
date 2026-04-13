import 'package:equatable/equatable.dart';
import '../../domain/entities/role_assignment.dart';

/// Modelo de asignación de rol para la capa de datos
class RoleAssignmentModel extends Equatable {
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

  const RoleAssignmentModel({
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

  factory RoleAssignmentModel.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as Map<String, dynamic>?;
    final section = json['club_section'] as Map<String, dynamic>?;
    final club = section?['club'] as Map<String, dynamic>?;

    return RoleAssignmentModel(
      id: (json['id'] ?? json['assignment_id']) as int,
      clubSectionId:
          (json['club_section_id'] ?? section?['id'] ?? 0) as int,
      userId: (json['user_id'] ?? '') as String,
      roleId: (json['role_id'] ?? role?['id'] ?? 0) as int,
      roleName: role?['name'] as String? ?? json['role_name'] as String?,
      clubName: club?['name'] as String? ?? json['club_name'] as String?,
      sectionName:
          section?['name'] as String? ?? json['section_name'] as String?,
      status: json['status'] as String? ?? 'pending',
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'] as String)
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  RoleAssignment toEntity() {
    return RoleAssignment(
      id: id,
      clubSectionId: clubSectionId,
      userId: userId,
      roleId: roleId,
      roleName: roleName,
      clubName: clubName,
      sectionName: sectionName,
      status: status,
      assignedAt: assignedAt,
      revokedAt: revokedAt,
      notes: notes,
    );
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
