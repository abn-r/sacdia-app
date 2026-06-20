import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/class_counselor_assignment.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

class ClassCounselorPersonModel extends Equatable {
  final String userId;
  final String name;
  final String paternalLastName;
  final String maternalLastName;
  final String email;
  final String? userImage;

  const ClassCounselorPersonModel({
    required this.userId,
    required this.name,
    required this.paternalLastName,
    required this.maternalLastName,
    required this.email,
    this.userImage,
  });

  factory ClassCounselorPersonModel.fromJson(Map<String, dynamic> json) {
    return ClassCounselorPersonModel(
      userId: safeString(json['user_id']),
      name: safeString(json['name']),
      paternalLastName: safeString(json['paternal_last_name']),
      maternalLastName: safeString(json['maternal_last_name']),
      email: safeString(json['email']),
      userImage: safeStringOrNull(json['user_image']),
    );
  }

  ClassCounselorPerson toEntity() {
    return ClassCounselorPerson(
      userId: userId,
      name: name,
      paternalLastName: paternalLastName,
      maternalLastName: maternalLastName,
      email: email,
      userImage: userImage,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        name,
        paternalLastName,
        maternalLastName,
        email,
        userImage,
      ];
}

class ClassCounselorAssignmentClassModel extends Equatable {
  final int classId;
  final String name;
  final int clubTypeId;
  final int displayOrder;

  const ClassCounselorAssignmentClassModel({
    required this.classId,
    required this.name,
    required this.clubTypeId,
    required this.displayOrder,
  });

  factory ClassCounselorAssignmentClassModel.fromJson(
      Map<String, dynamic> json) {
    return ClassCounselorAssignmentClassModel(
      classId: safeInt(json['class_id']),
      name: safeString(json['name']),
      clubTypeId: safeInt(json['club_type_id']),
      displayOrder: safeInt(json['display_order']),
    );
  }

  ClassCounselorAssignmentClass toEntity() {
    return ClassCounselorAssignmentClass(
      classId: classId,
      name: name,
      clubTypeId: clubTypeId,
      displayOrder: displayOrder,
    );
  }

  @override
  List<Object?> get props => [
        classId,
        name,
        clubTypeId,
        displayOrder,
      ];
}

class ClassRoleAssignmentModel extends Equatable {
  final String assignmentId;
  final String roleName;

  const ClassRoleAssignmentModel({
    required this.assignmentId,
    required this.roleName,
  });

  factory ClassRoleAssignmentModel.fromJson(Map<String, dynamic> json) {
    final role = json['roles'] as Map<String, dynamic>?;

    return ClassRoleAssignmentModel(
      assignmentId: safeString(json['assignment_id']),
      roleName: safeString(role?['role_name']),
    );
  }

  ClassRoleAssignment toEntity() {
    return ClassRoleAssignment(
      assignmentId: assignmentId,
      roleName: roleName,
    );
  }

  @override
  List<Object?> get props => [assignmentId, roleName];
}

class ClassCounselorAssignmentModel extends Equatable {
  final String assignmentId;
  final String userId;
  final int clubSectionId;
  final int classId;
  final int ecclesiasticalYearId;
  final String clubRoleAssignmentId;
  final String responsibilityType;
  final bool active;
  final bool exceptional;
  final String? exceptionReason;
  final String assignedById;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final ClassCounselorPersonModel user;
  final ClassCounselorPersonModel assignedBy;
  final ClassCounselorAssignmentClassModel clazz;
  final ClassRoleAssignmentModel? classRoleAssignment;

  const ClassCounselorAssignmentModel({
    required this.assignmentId,
    required this.userId,
    required this.clubSectionId,
    required this.classId,
    required this.ecclesiasticalYearId,
    required this.clubRoleAssignmentId,
    required this.responsibilityType,
    required this.active,
    required this.exceptional,
    required this.exceptionReason,
    required this.assignedById,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.modifiedAt,
    required this.user,
    required this.assignedBy,
    required this.clazz,
    required this.classRoleAssignment,
  });

  factory ClassCounselorAssignmentModel.fromJson(Map<String, dynamic> json) {
    final usersJson = json['users'] as Map<String, dynamic>?;
    final assignedByJson = json['assigned_by'] as Map<String, dynamic>?;
    final classJson = json['classes'] as Map<String, dynamic>?;
    final clubRoleAssignmentJson =
        json['club_role_assignments'] as Map<String, dynamic>?;

    final userModel = usersJson != null
        ? ClassCounselorPersonModel.fromJson(usersJson)
        : const ClassCounselorPersonModel(
            userId: '',
            name: '',
            paternalLastName: '',
            maternalLastName: '',
            email: '',
          );

    final assignedByModel = assignedByJson != null
        ? ClassCounselorPersonModel.fromJson(assignedByJson)
        : const ClassCounselorPersonModel(
            userId: '',
            name: '',
            paternalLastName: '',
            maternalLastName: '',
            email: '',
          );

    return ClassCounselorAssignmentModel(
      assignmentId: safeString(json['assignment_id']),
      userId: safeString(json['user_id']),
      clubSectionId: safeInt(json['club_section_id']),
      classId: safeInt(json['class_id']),
      ecclesiasticalYearId: safeInt(json['ecclesiastical_year_id']),
      clubRoleAssignmentId: safeString(json['club_role_assignment_id']),
      responsibilityType: safeString(json['responsibility_type']),
      active: safeBool(json['active'], true),
      exceptional: safeBool(json['exceptional']),
      exceptionReason: safeStringOrNull(json['exception_reason']),
      assignedById: safeString(json['assigned_by_id']),
      startDate: _parseDateTime(json['start_date']),
      endDate: _parseDateTime(json['end_date']),
      createdAt: _parseDateTime(json['created_at']),
      modifiedAt: _parseDateTime(json['modified_at']),
      user: userModel,
      assignedBy: assignedByModel,
      clazz: classJson != null
          ? ClassCounselorAssignmentClassModel.fromJson(classJson)
          : const ClassCounselorAssignmentClassModel(
              classId: 0,
              name: '',
              clubTypeId: 0,
              displayOrder: 0,
            ),
      classRoleAssignment: clubRoleAssignmentJson != null
          ? ClassRoleAssignmentModel.fromJson(clubRoleAssignmentJson)
          : null,
    );
  }

  ClassCounselorAssignment toEntity() {
    return ClassCounselorAssignment(
      assignmentId: assignmentId,
      userId: userId,
      clubSectionId: clubSectionId,
      classId: classId,
      ecclesiasticalYearId: ecclesiasticalYearId,
      clubRoleAssignmentId: clubRoleAssignmentId,
      responsibilityType: responsibilityType,
      active: active,
      exceptional: exceptional,
      exceptionReason: exceptionReason,
      assignedById: assignedById,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      user: user.toEntity(),
      assignedBy: assignedBy.toEntity(),
      clazz: clazz.toEntity(),
      classRoleAssignment: classRoleAssignment?.toEntity(),
    );
  }

  @override
  List<Object?> get props => [
        assignmentId,
        userId,
        clubSectionId,
        classId,
        ecclesiasticalYearId,
        clubRoleAssignmentId,
        responsibilityType,
        active,
        exceptional,
        exceptionReason,
        assignedById,
        startDate,
        endDate,
        createdAt,
        modifiedAt,
        user,
        assignedBy,
        clazz,
        classRoleAssignment,
      ];
}
