import 'package:equatable/equatable.dart';

class MasterHonorRoadmap extends Equatable {
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
  final List<MasterHonorRoadmapGroup> requirementGroups;

  const MasterHonorRoadmap({
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

class MasterHonorRoadmapGroup extends Equatable {
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
  final List<MasterHonorRoadmapOption> options;

  const MasterHonorRoadmapGroup({
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

  bool get isCategoryCount => groupType == 'CATEGORY_COUNT';

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

class MasterHonorRoadmapOption extends Equatable {
  final int optionId;
  final String label;
  final bool completed;
  final List<int> honorIds;
  final List<int> completedHonorIds;

  const MasterHonorRoadmapOption({
    required this.optionId,
    required this.label,
    required this.completed,
    required this.honorIds,
    required this.completedHonorIds,
  });

  @override
  List<Object?> get props => [
        optionId,
        label,
        completed,
        honorIds,
        completedHonorIds,
      ];
}
