import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/class_members_progress.dart';
import '../../domain/entities/class_progress_summary.dart';
import 'class_progress_parsing.dart';

class ClassMemberProgressModel extends Equatable {
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
  final RequirementStatusCounts statusCounts;

  const ClassMemberProgressModel({
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

  factory ClassMemberProgressModel.fromJson(Map<String, dynamic> json) {
    return ClassMemberProgressModel(
      userId: safeString(json['user_id']),
      name: safeString(json['name']),
      enrollmentId: safeInt(json['enrollment_id']),
      classId: safeInt(json['class_id']),
      ecclesiasticalYearId: safeInt(json['ecclesiastical_year_id']),
      investitureStatus: safeString(json['investiture_status']),
      completedSections: safeInt(json['completed_sections']),
      totalSections: safeInt(json['total_sections']),
      overallProgress: safeInt(json['overall_progress']),
      crossTypeEnrollment: json['cross_type_enrollment'] == true,
      statusCounts: parseStatusCounts(json['status_counts']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'enrollment_id': enrollmentId,
      'class_id': classId,
      'ecclesiastical_year_id': ecclesiasticalYearId,
      'investiture_status': investitureStatus,
      'completed_sections': completedSections,
      'total_sections': totalSections,
      'overall_progress': overallProgress,
      'cross_type_enrollment': crossTypeEnrollment,
      'status_counts': statusCountsToJson(statusCounts),
    };
  }

  ClassMemberProgress toEntity() {
    return ClassMemberProgress(
      userId: userId,
      name: name,
      enrollmentId: enrollmentId,
      classId: classId,
      ecclesiasticalYearId: ecclesiasticalYearId,
      investitureStatus: investitureStatus,
      completedSections: completedSections,
      totalSections: totalSections,
      overallProgress: overallProgress,
      crossTypeEnrollment: crossTypeEnrollment,
      statusCounts: statusCounts,
    );
  }

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

class ClassMembersProgressResultModel extends Equatable {
  final int clubSectionId;
  final int clubTypeId;
  final int classId;
  final int ecclesiasticalYearId;
  final String accessLevel;
  final List<ClassMemberProgressModel> members;
  final ClassProgressSummary summary;
  final ClassResponsible? counselor;
  final ClassResponsible? assistant;

  const ClassMembersProgressResultModel({
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

  factory ClassMembersProgressResultModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? const [];
    final rawSummary = json['summary'];

    return ClassMembersProgressResultModel(
      clubSectionId: safeInt(json['club_section_id']),
      clubTypeId: safeInt(json['club_type_id']),
      classId: safeInt(json['class_id']),
      ecclesiasticalYearId: safeInt(json['ecclesiastical_year_id']),
      accessLevel: safeString(json['access_level']),
      members: rawMembers
          .map(
            (item) => ClassMemberProgressModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      summary: rawSummary is Map
          ? ClassProgressSummary(
              avgProgress: parseProgressPercent(rawSummary['avg_progress']),
              statusCounts: parseStatusCounts(rawSummary['status_counts']),
            )
          : const ClassProgressSummary(),
      counselor: parseResponsible(json['counselor']),
      assistant: parseResponsible(json['assistant']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'club_section_id': clubSectionId,
      'club_type_id': clubTypeId,
      'class_id': classId,
      'ecclesiastical_year_id': ecclesiasticalYearId,
      'access_level': accessLevel,
      'members': members.map((item) => item.toJson()).toList(),
      'summary': {
        'avg_progress': summary.avgProgress,
        'status_counts': statusCountsToJson(summary.statusCounts),
      },
      'counselor': responsibleToJson(counselor),
      'assistant': responsibleToJson(assistant),
    };
  }

  ClassMembersProgressResult toEntity() {
    return ClassMembersProgressResult(
      clubSectionId: clubSectionId,
      clubTypeId: clubTypeId,
      classId: classId,
      ecclesiasticalYearId: ecclesiasticalYearId,
      accessLevel: accessLevel,
      members: members.map((item) => item.toEntity()).toList(),
      summary: summary,
      counselor: counselor,
      assistant: assistant,
    );
  }

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
