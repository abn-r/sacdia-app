import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/class_progress_summary.dart';
import '../../domain/entities/progress_scope.dart';
import 'class_progress_parsing.dart';

class ProgressScopeClassModel extends Equatable {
  final int classId;
  final String name;
  final int clubTypeId;
  final String accessLevel;
  final int membersCount;
  final int avgProgress;
  final RequirementStatusCounts statusCounts;
  final ClassResponsible? counselor;
  final ClassResponsible? assistant;

  const ProgressScopeClassModel({
    required this.classId,
    required this.name,
    required this.clubTypeId,
    required this.accessLevel,
    this.membersCount = 0,
    this.avgProgress = 0,
    this.statusCounts = RequirementStatusCounts.zero,
    this.counselor,
    this.assistant,
  });

  factory ProgressScopeClassModel.fromJson(Map<String, dynamic> json) {
    return ProgressScopeClassModel(
      classId: safeInt(json['class_id']),
      name: safeString(json['name']),
      clubTypeId: safeInt(json['club_type_id']),
      accessLevel: safeString(json['access_level']),
      membersCount: safeInt(json['members_count']),
      avgProgress: parseProgressPercent(json['avg_progress']),
      statusCounts: parseStatusCounts(json['status_counts']),
      counselor: parseResponsible(json['counselor']),
      assistant: parseResponsible(json['assistant']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'name': name,
      'club_type_id': clubTypeId,
      'access_level': accessLevel,
      'members_count': membersCount,
      'avg_progress': avgProgress,
      'status_counts': statusCountsToJson(statusCounts),
      'counselor': responsibleToJson(counselor),
      'assistant': responsibleToJson(assistant),
    };
  }

  ProgressScopeClass toEntity() {
    return ProgressScopeClass(
      classId: classId,
      name: name,
      clubTypeId: clubTypeId,
      accessLevel: accessLevel,
      membersCount: membersCount,
      avgProgress: avgProgress,
      statusCounts: statusCounts,
      counselor: counselor,
      assistant: assistant,
    );
  }

  @override
  List<Object?> get props => [
        classId,
        name,
        clubTypeId,
        accessLevel,
        membersCount,
        avgProgress,
        statusCounts,
        counselor,
        assistant,
      ];
}

class ProgressScopeResultModel extends Equatable {
  final int clubSectionId;
  final int clubTypeId;
  final int ecclesiasticalYearId;
  final String accessLevel;
  final List<ProgressScopeClassModel> classes;

  const ProgressScopeResultModel({
    required this.clubSectionId,
    required this.clubTypeId,
    required this.ecclesiasticalYearId,
    required this.accessLevel,
    required this.classes,
  });

  factory ProgressScopeResultModel.fromJson(Map<String, dynamic> json) {
    final rawClasses = json['classes'] as List<dynamic>? ?? const [];

    return ProgressScopeResultModel(
      clubSectionId: safeInt(json['club_section_id']),
      clubTypeId: safeInt(json['club_type_id']),
      ecclesiasticalYearId: safeInt(json['ecclesiastical_year_id']),
      accessLevel: safeString(json['access_level']),
      classes: rawClasses
          .map(
            (item) => ProgressScopeClassModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'club_section_id': clubSectionId,
      'club_type_id': clubTypeId,
      'ecclesiastical_year_id': ecclesiasticalYearId,
      'access_level': accessLevel,
      'classes': classes.map((item) => item.toJson()).toList(),
    };
  }

  ProgressScopeResult toEntity() {
    return ProgressScopeResult(
      clubSectionId: clubSectionId,
      clubTypeId: clubTypeId,
      ecclesiasticalYearId: ecclesiasticalYearId,
      accessLevel: accessLevel,
      classes: classes.map((item) => item.toEntity()).toList(),
    );
  }

  @override
  List<Object?> get props => [
        clubSectionId,
        clubTypeId,
        ecclesiasticalYearId,
        accessLevel,
        classes,
      ];
}
