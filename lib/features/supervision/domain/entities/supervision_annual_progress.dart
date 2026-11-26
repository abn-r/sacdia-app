import 'package:equatable/equatable.dart';

/// A union or local field the actor can pick.
///
/// [clubsCount], [configured] and [goldOrBetterCount] come from
/// `GET /annual-rankings/territory-summary`; they stay null when the server
/// is older than that endpoint (names only, from the catalogs).
class SupervisionTerritoryOption extends Equatable {
  const SupervisionTerritoryOption({
    required this.id,
    this.name = '',
    this.clubsCount,
    this.configured,
    this.goldOrBetterCount,
  });

  final int id;
  final String name;

  /// Clubs under this territory; null when the server did not say.
  final int? clubsCount;

  /// False: it has no annual configuration yet. Null: not known.
  final bool? configured;

  /// Clubs with at least one section at gold or better. Null: the server has
  /// not computed it yet for the year, or does not send it. Never read as 0.
  final int? goldOrBetterCount;

  @override
  List<Object?> get props =>
      [id, name, clubsCount, configured, goldOrBetterCount];
}

class SupervisionProgressTier extends Equatable {
  const SupervisionProgressTier({
    this.name = '',
    this.slug = '',
    this.fromPoints = 0,
    this.toPoints = 0,
    this.pointsToReach,
  });

  final String name;
  final String slug;
  final double fromPoints;
  final double toPoints;
  final double? pointsToReach;

  @override
  List<Object?> get props => [name, slug, fromPoints, toPoints, pointsToReach];
}

class SupervisionProgressComponent extends Equatable {
  const SupervisionProgressComponent({
    required this.key,
    this.label = '',
    this.earnedPoints = 0,
    this.maxPoints = 0,
    this.progressPercentage = 0,
  });

  final String key;
  final String label;
  final double earnedPoints;
  final double maxPoints;

  /// 0..100.
  final double progressPercentage;

  @override
  List<Object?> get props =>
      [key, label, earnedPoints, maxPoints, progressPercentage];
}

class SupervisionProgressAxis extends Equatable {
  const SupervisionProgressAxis({
    required this.key,
    this.label = '',
    this.earnedPoints = 0,
    this.maxPoints = 0,
    this.progressPercentage = 0,
    this.components = const [],
  });

  final String key;
  final String label;
  final double earnedPoints;
  final double maxPoints;

  /// 0..100.
  final double progressPercentage;
  final List<SupervisionProgressComponent> components;

  @override
  List<Object?> get props =>
      [key, label, earnedPoints, maxPoints, progressPercentage, components];
}

class SupervisionClubProgress extends Equatable {
  const SupervisionClubProgress({
    required this.clubId,
    required this.clubSectionId,
    this.clubName = '',
    this.currentPoints = 0,
    this.maxPoints = 0,
    this.progressPercentage = 0,
    this.currentTier,
    this.nextTier,
    this.axes = const [],
    this.components = const [],
  });

  final int clubId;
  final int clubSectionId;
  final String clubName;
  final double currentPoints;
  final double maxPoints;

  /// 0..100, clamped.
  final double progressPercentage;
  final SupervisionProgressTier? currentTier;
  final SupervisionProgressTier? nextTier;
  final List<SupervisionProgressAxis> axes;
  final List<SupervisionProgressComponent> components;

  @override
  List<Object?> get props => [
        clubId,
        clubSectionId,
        clubName,
        currentPoints,
        maxPoints,
        progressPercentage,
        currentTier,
        nextTier,
        axes,
        components,
      ];
}

/// Annual progress of the clubs of one local field, club type and year.
///
/// `configured == false`: the local field has no annual configuration for
/// that club type and year (server 404 ANNUAL_RANKING_CONFIG_NOT_FOUND).
class SupervisionAnnualProgress extends Equatable {
  const SupervisionAnnualProgress({
    required this.configured,
    this.clubs = const [],
  });

  final bool configured;
  final List<SupervisionClubProgress> clubs;

  @override
  List<Object?> get props => [configured, clubs];
}

typedef SupervisionAnnualProgressQuery = ({
  int localFieldId,
  int clubTypeId,
  int yearId,
});
