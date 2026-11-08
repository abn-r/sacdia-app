import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/camporee_leaderboard.dart';

class CamporeeLeaderboardModel extends Equatable {
  final String scopeType;
  final int camporeeId;

  /// `visibility: 'own'` = solo las secciones propias, sin posición. Un
  /// servidor anterior (sin el campo) siempre mandaba la tabla completa.
  final bool isFullRanking;
  final List<CamporeeLeaderboardRowModel> rows;

  const CamporeeLeaderboardModel({
    required this.scopeType,
    required this.camporeeId,
    required this.rows,
    this.isFullRanking = true,
  });

  factory CamporeeLeaderboardModel.fromJson(Map<String, dynamic> json) {
    final scope = json['scope'];
    final scopeMap = scope is Map ? Map<String, dynamic>.from(scope) : const {};
    final rawRows = json['rows'];
    return CamporeeLeaderboardModel(
      scopeType: safeString(scopeMap['type'], 'local'),
      camporeeId: safeInt(scopeMap['camporeeId'] ?? scopeMap['camporee_id']),
      isFullRanking: json['visibility'] != 'own',
      rows: rawRows is List
          ? rawRows
              .whereType<Map>()
              .map(
                (row) => CamporeeLeaderboardRowModel.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList()
          : const [],
    );
  }

  CamporeeLeaderboard toEntity() {
    return CamporeeLeaderboard(
      scopeType: scopeType,
      camporeeId: camporeeId,
      isFullRanking: isFullRanking,
      rows: rows.map((row) => row.toEntity()).toList(),
    );
  }

  @override
  List<Object?> get props => [scopeType, camporeeId, isFullRanking, rows];
}

class CamporeeLeaderboardRowModel extends Equatable {
  final int? rank;
  final int? camporeeClubId;
  final int clubSectionId;
  final String? clubName;
  final String? sectionName;
  final double totalAwardedPoints;
  final double totalMaxPoints;
  final double percentage;

  const CamporeeLeaderboardRowModel({
    this.rank,
    this.camporeeClubId,
    required this.clubSectionId,
    this.clubName,
    this.sectionName,
    required this.totalAwardedPoints,
    required this.totalMaxPoints,
    required this.percentage,
  });

  factory CamporeeLeaderboardRowModel.fromJson(Map<String, dynamic> json) {
    return CamporeeLeaderboardRowModel(
      rank: safeIntOrNull(json['rank']),
      camporeeClubId: safeIntOrNull(json['camporee_club_id']),
      clubSectionId: safeInt(json['club_section_id']),
      clubName: safeStringOrNull(json['club_name']),
      sectionName: safeStringOrNull(json['section_name']),
      totalAwardedPoints: safeDouble(json['total_awarded_points']),
      totalMaxPoints: safeDouble(json['total_max_points']),
      percentage: safeDouble(json['percentage']),
    );
  }

  CamporeeLeaderboardRow toEntity() {
    return CamporeeLeaderboardRow(
      rank: rank,
      camporeeClubId: camporeeClubId,
      clubSectionId: clubSectionId,
      clubName: clubName,
      sectionName: sectionName,
      totalAwardedPoints: totalAwardedPoints,
      totalMaxPoints: totalMaxPoints,
      percentage: percentage,
    );
  }

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
