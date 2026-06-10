import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/master_honor_roadmap.dart';

class MasterHonorRoadmapModel extends Equatable {
  final int masterHonorId;
  final String name;
  final String? masterImage;
  final String? status;
  final bool isCurrent;
  final bool isAwarded;
  final String? displayStatusLabel;
  final int completedGroups;
  final int totalGroups;
  final int progressPercent;
  final List<MasterHonorRoadmapGroupModel> requirementGroups;

  const MasterHonorRoadmapModel({
    required this.masterHonorId,
    required this.name,
    this.masterImage,
    this.status,
    required this.isCurrent,
    required this.isAwarded,
    this.displayStatusLabel,
    required this.completedGroups,
    required this.totalGroups,
    required this.progressPercent,
    required this.requirementGroups,
  });

  factory MasterHonorRoadmapModel.fromJson(Map<String, dynamic> json) {
    return MasterHonorRoadmapModel(
      masterHonorId: safeInt(json['master_honor_id']),
      name: safeString(json['name']),
      masterImage: safeStringOrNull(json['master_image']),
      status: safeStringOrNull(json['status']),
      isCurrent: safeBool(json['is_current']),
      isAwarded: safeBool(json['is_awarded']),
      displayStatusLabel: safeStringOrNull(json['display_status_label']),
      completedGroups: safeInt(json['completed_groups']),
      totalGroups: safeInt(json['total_groups']),
      progressPercent: safeInt(json['progress_percent']),
      requirementGroups: _parseGroups(json['requirement_groups']),
    );
  }

  MasterHonorRoadmap toEntity() {
    return MasterHonorRoadmap(
      masterHonorId: masterHonorId,
      name: name,
      masterImage: masterImage,
      status: status,
      isCurrent: isCurrent,
      isAwarded: isAwarded,
      displayStatusLabel: displayStatusLabel,
      completedGroups: completedGroups,
      totalGroups: totalGroups,
      progressPercent: progressPercent,
      requirementGroups:
          requirementGroups.map((group) => group.toEntity()).toList(),
    );
  }

  static List<MasterHonorRoadmapGroupModel> _parseGroups(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(MasterHonorRoadmapGroupModel.fromJson)
        .toList();
  }

  @override
  List<Object?> get props => [
        masterHonorId,
        name,
        masterImage,
        status,
        isCurrent,
        isAwarded,
        displayStatusLabel,
        completedGroups,
        totalGroups,
        progressPercent,
        requirementGroups,
      ];
}

class MasterHonorRoadmapGroupModel extends Equatable {
  final int groupId;
  final String groupType;
  final String? title;
  final String? description;
  final int minimumRequired;
  final int currentCount;
  final bool passed;
  final int? honorsCategoryId;
  final String? categoryName;
  final List<int> matchedHonorIds;
  final List<MasterHonorRoadmapOptionModel> options;

  const MasterHonorRoadmapGroupModel({
    required this.groupId,
    required this.groupType,
    this.title,
    this.description,
    required this.minimumRequired,
    required this.currentCount,
    required this.passed,
    this.honorsCategoryId,
    this.categoryName,
    required this.matchedHonorIds,
    required this.options,
  });

  factory MasterHonorRoadmapGroupModel.fromJson(Map<String, dynamic> json) {
    return MasterHonorRoadmapGroupModel(
      groupId: safeInt(json['group_id']),
      groupType: safeString(json['group_type']),
      title: safeStringOrNull(json['title']),
      description: safeStringOrNull(json['description']),
      minimumRequired: safeInt(json['minimum_required']),
      currentCount: safeInt(json['current_count']),
      passed: safeBool(json['passed']),
      honorsCategoryId: safeIntOrNull(json['honors_category_id']),
      categoryName: safeStringOrNull(json['category_name']),
      matchedHonorIds: _parseIntList(json['matched_honor_ids']),
      options: _parseOptions(json['options']),
    );
  }

  MasterHonorRoadmapGroup toEntity() {
    return MasterHonorRoadmapGroup(
      groupId: groupId,
      groupType: groupType,
      title: title,
      description: description,
      minimumRequired: minimumRequired,
      currentCount: currentCount,
      passed: passed,
      honorsCategoryId: honorsCategoryId,
      categoryName: categoryName,
      matchedHonorIds: matchedHonorIds,
      options: options.map((option) => option.toEntity()).toList(),
    );
  }

  static List<MasterHonorRoadmapOptionModel> _parseOptions(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(MasterHonorRoadmapOptionModel.fromJson)
        .toList();
  }

  @override
  List<Object?> get props => [
        groupId,
        groupType,
        title,
        description,
        minimumRequired,
        currentCount,
        passed,
        honorsCategoryId,
        categoryName,
        matchedHonorIds,
        options,
      ];
}

class MasterHonorRoadmapOptionModel extends Equatable {
  final int optionId;
  final String label;
  final bool completed;
  final List<int> honorIds;
  final List<int> completedHonorIds;

  const MasterHonorRoadmapOptionModel({
    required this.optionId,
    required this.label,
    required this.completed,
    required this.honorIds,
    required this.completedHonorIds,
  });

  factory MasterHonorRoadmapOptionModel.fromJson(Map<String, dynamic> json) {
    return MasterHonorRoadmapOptionModel(
      optionId: safeInt(json['option_id']),
      label: safeString(json['label']),
      completed: safeBool(json['completed']),
      honorIds: _parseIntList(json['honor_ids']),
      completedHonorIds: _parseIntList(json['completed_honor_ids']),
    );
  }

  MasterHonorRoadmapOption toEntity() {
    return MasterHonorRoadmapOption(
      optionId: optionId,
      label: label,
      completed: completed,
      honorIds: honorIds,
      completedHonorIds: completedHonorIds,
    );
  }

  @override
  List<Object?> get props => [
        optionId,
        label,
        completed,
        honorIds,
        completedHonorIds,
      ];
}

List<int> _parseIntList(dynamic value) {
  if (value is! List) return const [];
  return value.map(safeInt).where((id) => id > 0).toList();
}
