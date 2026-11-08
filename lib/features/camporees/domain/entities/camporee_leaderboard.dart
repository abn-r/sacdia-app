import 'package:equatable/equatable.dart';

/// Clasificación oficial de un camporee (local o de unión).
class CamporeeLeaderboard extends Equatable {
  final String scopeType;
  final int camporeeId;

  /// `true` solo para el lado administrativo (admins, campo local, unión,
  /// división y pastores): todas las secciones con su posición. Los roles de
  /// club reciben solo sus propias secciones, sin posición.
  final bool isFullRanking;
  final List<CamporeeLeaderboardRow> rows;

  const CamporeeLeaderboard({
    required this.scopeType,
    required this.camporeeId,
    required this.rows,
    this.isFullRanking = true,
  });

  @override
  List<Object?> get props => [scopeType, camporeeId, isFullRanking, rows];
}

class CamporeeLeaderboardRow extends Equatable {
  /// Posición en la clasificación completa; `null` en la vista propia.
  final int? rank;
  final int? camporeeClubId;
  final int clubSectionId;
  final String? clubName;
  final String? sectionName;
  final double totalAwardedPoints;
  final double totalMaxPoints;
  final double percentage;

  const CamporeeLeaderboardRow({
    this.rank,
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
