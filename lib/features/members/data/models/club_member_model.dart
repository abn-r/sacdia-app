import '../../domain/entities/club_member.dart';

/// Modelo de datos de un miembro del club
class ClubMemberModel extends ClubMember {
  const ClubMemberModel({
    required super.userId,
    required super.name,
    super.paternalSurname,
    super.maternalSurname,
    super.avatar,
    super.email,
    super.phone,
    super.birthDate,
    super.gender,
    super.clubRole,
    super.clubRoleAssignmentId,
    super.currentClass,
    super.currentClassId,
    super.isEnrolled,
    super.clubSectionId,
    super.blood,
    super.address,
    super.baptism,
    super.baptismDate,
  });

  /// Crea un ClubMemberModel a partir de la respuesta de la API.
  ///
  /// La API devuelve objetos en el endpoint:
  /// GET /api/v1/clubs/:clubId/sections/:sectionId/members
  factory ClubMemberModel.fromJson(Map<String, dynamic> json) {
    // El campo user puede venir anidado o plano
    final user = json['user'] as Map<String, dynamic>? ??
        json['users'] as Map<String, dynamic>? ??
        json;

    // Clase actual del miembro
    final currentClassData = json['current_class'] as Map<String, dynamic>? ??
        user['current_class'] as Map<String, dynamic>?;

    // Rol asignado en el club
    final roleData = json['club_role'] as Map<String, dynamic>? ??
        json['role'] as Map<String, dynamic>? ??
        json['roles'] as Map<String, dynamic>?;
    final roleString = json['role'] is String ? json['role'] as String : null;

    // Fecha de nacimiento
    final birthdayRaw =
        user['birthday'] as String? ?? user['birth_date'] as String?;

    // Fecha de bautismo
    final baptismDateRaw = user['baptism_date'] as String? ??
        json['baptism_date'] as String?;

    return ClubMemberModel(
      userId: user['user_id'] as String? ??
          user['id'] as String? ??
          json['user_id'] as String? ??
          '',
      name: user['name'] as String? ?? '',
      paternalSurname: user['paternal_last_name'] as String? ??
          user['p_lastname'] as String?,
      maternalSurname: user['maternal_last_name'] as String? ??
          user['m_lastname'] as String?,
      avatar: user['user_image'] as String? ?? user['avatar'] as String?,
      email: user['email'] as String?,
      phone: user['phone'] as String?,
      birthDate: birthdayRaw != null ? DateTime.tryParse(birthdayRaw) : null,
      gender: user['gender'] as String?,
      clubRole: roleData?['name'] as String? ??
          roleData?['role_name'] as String? ??
          roleData?['role'] as String? ??
          roleString ??
          json['club_role_name'] as String?,
      clubRoleAssignmentId: json['assignment_id']?.toString() ??
          json['club_role_assignment_id']?.toString() ??
          json['id']?.toString(),
      currentClass: currentClassData?['name'] as String?,
      currentClassId: currentClassData?['id'] is int
          ? currentClassData!['id'] as int
          : int.tryParse(currentClassData?['id']?.toString() ?? ''),
      isEnrolled:
          json['is_enrolled'] as bool? ?? json['enrolled'] as bool? ?? true,
      clubSectionId: json['club_section_id'] is int
          ? json['club_section_id'] as int
          : int.tryParse(json['club_section_id']?.toString() ?? ''),
      blood: user['blood'] as String? ?? json['blood'] as String?,
      address: user['address'] as String? ?? json['address'] as String?,
      baptism: user['baptism'] as bool? ?? json['baptism'] as bool?,
      baptismDate:
          baptismDateRaw != null ? DateTime.tryParse(baptismDateRaw) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'paternal_last_name': paternalSurname,
      'maternal_last_name': maternalSurname,
      'user_image': avatar,
      'email': email,
      'phone': phone,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'club_role': clubRole,
      'assignment_id': clubRoleAssignmentId,
      'current_class': currentClass,
      'is_enrolled': isEnrolled,
    };
  }
}
