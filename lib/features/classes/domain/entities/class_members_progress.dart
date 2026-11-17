import 'package:equatable/equatable.dart';

import 'class_progress_summary.dart';

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
  final bool crossTypeEnrollment;

  /// This member's requirements by status.
  final RequirementStatusCounts statusCounts;

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
    this.crossTypeEnrollment = false,
    this.statusCounts = RequirementStatusCounts.zero,
  });

  /// Behind schedule: less than 40% of the way through the class.
  bool get isBehind => overallProgress < 40;

  /// Has requirements the local field sent back.
  bool get hasRejected => statusCounts.rejected > 0;

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
        crossTypeEnrollment,
        statusCounts,
      ];
}

class ClassMembersProgressResult extends Equatable {
  final int clubSectionId;
  final int clubTypeId;
  final int classId;
  final int ecclesiasticalYearId;
  final String accessLevel;
  final List<ClassMemberProgress> members;
  final ClassProgressSummary summary;
  final ClassResponsible? counselor;
  final ClassResponsible? assistant;

  const ClassMembersProgressResult({
    required this.clubSectionId,
    required this.clubTypeId,
    required this.classId,
    required this.ecclesiasticalYearId,
    required this.accessLevel,
    required this.members,
    this.summary = const ClassProgressSummary(),
    this.counselor,
    this.assistant,
  });

  @override
  List<Object?> get props => [
        clubSectionId,
        clubTypeId,
        classId,
        ecclesiasticalYearId,
        accessLevel,
        members,
        summary,
        counselor,
        assistant,
      ];
}
