import 'package:equatable/equatable.dart';

class AnnualRankingProgress extends Equatable {
  final int sectionId;
  final int clubId;
  final String clubName;
  final RankingClubType clubType;
  final RankingYear year;
  final int currentPoints;
  final int maxPoints;
  final double progressPercentage;
  final RankingTier? currentTier;
  final RankingTier? nextTier;
  final List<RankingComponentProgress> components;
  final List<RankingPendingItem> pendingItems;

  const AnnualRankingProgress({
    required this.sectionId,
    required this.clubId,
    required this.clubName,
    required this.clubType,
    required this.year,
    required this.currentPoints,
    required this.maxPoints,
    required this.progressPercentage,
    required this.currentTier,
    required this.nextTier,
    required this.components,
    required this.pendingItems,
  });

  @override
  List<Object?> get props => [
        sectionId,
        clubId,
        clubName,
        clubType,
        year,
        currentPoints,
        maxPoints,
        progressPercentage,
        currentTier,
        nextTier,
        components,
        pendingItems,
      ];
}

class RankingClubType extends Equatable {
  final int clubTypeId;
  final String name;

  const RankingClubType({
    required this.clubTypeId,
    required this.name,
  });

  @override
  List<Object?> get props => [clubTypeId, name];
}

class RankingYear extends Equatable {
  final int ecclesiasticalYearId;

  const RankingYear({required this.ecclesiasticalYearId});

  @override
  List<Object?> get props => [ecclesiasticalYearId];
}

class RankingTier extends Equatable {
  final String name;
  final String slug;
  final int fromPoints;
  final int toPoints;
  final int? pointsToReach;

  const RankingTier({
    required this.name,
    required this.slug,
    required this.fromPoints,
    required this.toPoints,
    this.pointsToReach,
  });

  @override
  List<Object?> get props => [
        name,
        slug,
        fromPoints,
        toPoints,
        pointsToReach,
      ];
}

class RankingComponentProgress extends Equatable {
  final String key;
  final String label;
  final int earnedPoints;
  final int maxPoints;
  final double progressPercentage;

  const RankingComponentProgress({
    required this.key,
    required this.label,
    required this.earnedPoints,
    required this.maxPoints,
    required this.progressPercentage,
  });

  @override
  List<Object?> get props => [
        key,
        label,
        earnedPoints,
        maxPoints,
        progressPercentage,
      ];
}

class RankingPendingItem extends Equatable {
  final String type;
  final String title;
  final String status;
  final String statusLabelKey;
  final DateTime? dueDate;
  final String actionLabel;

  const RankingPendingItem({
    required this.type,
    required this.title,
    required this.status,
    required this.statusLabelKey,
    required this.dueDate,
    required this.actionLabel,
  });

  @override
  List<Object?> get props => [
        type,
        title,
        status,
        statusLabelKey,
        dueDate,
        actionLabel,
      ];
}
