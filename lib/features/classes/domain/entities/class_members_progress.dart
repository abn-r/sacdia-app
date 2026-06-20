import 'package:equatable/equatable.dart';

class ClassMemberProgress extends Equatable {
  final String userId;
  final String name;
  final int enrollmentId;
  final int classId;
  final int ecclesiasticalYearId;
  final String investitureStatus;
  final int completedSections;
  final int totalSections;
  final int overallProgress;

  const ClassMemberProgress({
    required this.userId,
    required this.name,
    required this.enrollmentId,
    required this.classId,
    required this.ecclesiasticalYearId,
    required this.investitureStatus,
    required this.completedSections,
    required this.totalSections,
    required this.overallProgress,
  });

  @override
  List<Object?> get props => [
        userId,
        name,
        enrollmentId,
        classId,
        ecclesiasticalYearId,
        investitureStatus,
        completedSections,
        totalSections,
        overallProgress,
      ];
}

class ClassMembersProgressResult extends Equatable {
  final int clubSectionId;
  final int clubTypeId;
  final int classId;
  final int ecclesiasticalYearId;
  final String accessLevel;
  final List<ClassMemberProgress> members;

  const ClassMembersProgressResult({
    required this.clubSectionId,
    required this.clubTypeId,
    required this.classId,
    required this.ecclesiasticalYearId,
    required this.accessLevel,
    required this.members,
  });

  @override
  List<Object?> get props => [
        clubSectionId,
        clubTypeId,
        classId,
        ecclesiasticalYearId,
        accessLevel,
        members,
      ];
}
