import 'package:equatable/equatable.dart';

import 'class_progress_summary.dart';

class ProgressScopeClass extends Equatable {
  final int classId;
  final String name;
  final int clubTypeId;
  final String accessLevel;

  /// Members enrolled in the class this year.
  final int membersCount;

  /// Average progress of those members, 0-100.
  final int avgProgress;

  /// Requirements of all those members by status.
  final RequirementStatusCounts statusCounts;
  final ClassResponsible? counselor;
  final ClassResponsible? assistant;

  const ProgressScopeClass({
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

class ProgressScopeResult extends Equatable {
  final int clubSectionId;
  final int clubTypeId;
  final int ecclesiasticalYearId;
  final String accessLevel;
  final List<ProgressScopeClass> classes;

  const ProgressScopeResult({
    required this.clubSectionId,
    required this.clubTypeId,
    required this.ecclesiasticalYearId,
    required this.accessLevel,
    required this.classes,
  });

  bool get hasSectionWideAccess => accessLevel == 'section';

  /// Members across all the classes in scope.
  int get totalMembers => classes.fold(0, (sum, c) => sum + c.membersCount);

  /// Average progress weighted by members, so a class with more members
  /// weighs more. Zero when nobody is enrolled.
  int get weightedAvgProgress {
    final members = totalMembers;
    if (members == 0) return 0;
    final weighted = classes.fold<int>(
      0,
      (sum, c) => sum + c.avgProgress * c.membersCount,
    );
    return (weighted / members).round().clamp(0, 100);
  }

  RequirementStatusCounts get totalStatusCounts => classes.fold(
        RequirementStatusCounts.zero,
        (sum, c) => sum + c.statusCounts,
      );

  @override
  List<Object?> get props => [
        clubSectionId,
        clubTypeId,
        ecclesiasticalYearId,
        accessLevel,
        classes,
      ];
}
