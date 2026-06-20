import 'package:equatable/equatable.dart';

class ClassCounselorPerson extends Equatable {
  final String userId;
  final String name;
  final String paternalLastName;
  final String maternalLastName;
  final String email;
  final String? userImage;

  const ClassCounselorPerson({
    required this.userId,
    required this.name,
    required this.paternalLastName,
    required this.maternalLastName,
    required this.email,
    this.userImage,
  });

  String get fullLastName =>
      [paternalLastName, maternalLastName].where((x) => x.isNotEmpty).join(' ');

  String get displayName => [name, if (fullLastName.isNotEmpty) fullLastName]
      .where((x) => x.isNotEmpty)
      .join(' ');

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

class ClassCounselorAssignmentClass extends Equatable {
  final int classId;
  final String name;
  final int clubTypeId;
  final int displayOrder;

  const ClassCounselorAssignmentClass({
    required this.classId,
    required this.name,
    required this.clubTypeId,
    required this.displayOrder,
  });

  @override
  List<Object?> get props => [classId, name, clubTypeId, displayOrder];
}

class ClassRoleAssignment extends Equatable {
  final String assignmentId;
  final String roleName;

  const ClassRoleAssignment({
    required this.assignmentId,
    required this.roleName,
  });

  @override
  List<Object?> get props => [assignmentId, roleName];
}

class ClassCounselorAssignment extends Equatable {
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
  final ClassCounselorPerson user;
  final ClassCounselorPerson assignedBy;
  final ClassCounselorAssignmentClass clazz;
  final ClassRoleAssignment? classRoleAssignment;

  const ClassCounselorAssignment({
    required this.assignmentId,
    required this.userId,
    required this.clubSectionId,
    required this.classId,
    required this.ecclesiasticalYearId,
    required this.clubRoleAssignmentId,
    required this.responsibilityType,
    required this.active,
    required this.exceptional,
    this.exceptionReason,
    required this.assignedById,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.modifiedAt,
    required this.user,
    required this.assignedBy,
    required this.clazz,
    this.classRoleAssignment,
  });

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
