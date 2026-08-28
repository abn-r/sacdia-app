import 'package:equatable/equatable.dart';

/// Clasificación oficial de un camporee (local o de unión).
class CamporeeLeaderboard extends Equatable {
  final String scopeType;
  final int camporeeId;
  final List<CamporeeLeaderboardRow> rows;

  const CamporeeLeaderboard({
    required this.scopeType,
    required this.camporeeId,
    required this.rows,
  });

  @override
  List<Object?> get props => [scopeType, camporeeId, rows];
}

class CamporeeLeaderboardRow extends Equatable {
  final int rank;
  final int? camporeeClubId;
  final int clubSectionId;
  final String? clubName;
  final String? sectionName;
  final double totalAwardedPoints;
  final double totalMaxPoints;
  final double percentage;

  const CamporeeLeaderboardRow({
    required this.rank,
    this.camporeeClubId,
    required this.clubSectionId,
    this.clubName,
    this.sectionName,
    required this.totalAwardedPoints,
    required this.totalMaxPoints,
    required this.percentage,
  });

  @override
  List<Object?> get props => [
        rank,
        camporeeClubId,
        clubSectionId,
        clubName,
        sectionName,
        totalAwardedPoints,
        totalMaxPoints,
        percentage,
      ];
}
