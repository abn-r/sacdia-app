import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/camporee_score_breakdown.dart';
import 'camporee_official_score_model.dart';

class CamporeeScoreBreakdownModel extends Equatable {
  final String scopeType;
  final int camporeeId;
  final String visibility;
  final List<CamporeeScoreBreakdownSectionModel> sections;

  const CamporeeScoreBreakdownModel({
    required this.scopeType,
    required this.camporeeId,
    required this.visibility,
    required this.sections,
  });

  factory CamporeeScoreBreakdownModel.fromJson(Map<String, dynamic> json) {
    final scope = json['scope'];
    final scopeMap = scope is Map ? Map<String, dynamic>.from(scope) : const {};
    final rawSections = json['sections'];
    return CamporeeScoreBreakdownModel(
      scopeType: safeString(scopeMap['type'], 'local'),
      camporeeId: safeInt(scopeMap['camporeeId'] ?? scopeMap['camporee_id']),
      visibility: safeString(json['visibility'], 'full'),
      sections: rawSections is List
          ? rawSections
              .whereType<Map>()
              .map(
                (s) => CamporeeScoreBreakdownSectionModel.fromJson(
                  Map<String, dynamic>.from(s),
                ),
              )
              .toList()
          : const [],
    );
  }

  CamporeeScoreBreakdown toEntity() => CamporeeScoreBreakdown(
        scopeType: scopeType,
        camporeeId: camporeeId,
        visibility: visibility,
        sections: sections.map((s) => s.toEntity()).toList(),
      );

  @override
  List<Object?> get props => [scopeType, camporeeId, visibility, sections];
}

class CamporeeScoreBreakdownSectionModel extends Equatable {
  final int? rank;
  final int? camporeeClubId;
  final int clubSectionId;
  final String? clubName;
  final String? sectionName;
  final double totalAwardedPoints;
  final double totalMaxPoints;
  final List<CamporeeScoreBreakdownResultModel> results;

  const CamporeeScoreBreakdownSectionModel({
    this.rank,
    this.camporeeClubId,
    required this.clubSectionId,
    this.clubName,
    this.sectionName,
    required this.totalAwardedPoints,
    required this.totalMaxPoints,
    required this.results,
  });

  factory CamporeeScoreBreakdownSectionModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawResults = json['results'];
    return CamporeeScoreBreakdownSectionModel(
      rank: safeIntOrNull(json['rank']),
      camporeeClubId: safeIntOrNull(json['camporee_club_id']),
      clubSectionId: safeInt(json['club_section_id']),
      clubName: safeStringOrNull(json['club_name']),
      sectionName: safeStringOrNull(json['section_name']),
      totalAwardedPoints: safeDouble(json['total_awarded_points']),
      totalMaxPoints: safeDouble(json['total_max_points']),
      results: rawResults is List
          ? rawResults
              .whereType<Map>()
              .map(
                (r) => CamporeeScoreBreakdownResultModel.fromJson(
                  Map<String, dynamic>.from(r),
                ),
              )
              .toList()
          : const [],
    );
  }

  CamporeeScoreBreakdownSection toEntity() => CamporeeScoreBreakdownSection(
        rank: rank,
        camporeeClubId: camporeeClubId,
        clubSectionId: clubSectionId,
        clubName: clubName,
        sectionName: sectionName,
        totalAwardedPoints: totalAwardedPoints,
        totalMaxPoints: totalMaxPoints,
        results: results.map((r) => r.toEntity()).toList(),
      );

  @override
  List<Object?> get props => [
        rank,
        camporeeClubId,
        clubSectionId,
        clubName,
        sectionName,
        totalAwardedPoints,
        totalMaxPoints,
        results,
      ];
}

class CamporeeScoreBreakdownResultModel extends Equatable {
  final int camporeeEventId;
  final CamporeeOfficialScoreModel score;

  const CamporeeScoreBreakdownResultModel({
    required this.camporeeEventId,
    required this.score,
  });

  factory CamporeeScoreBreakdownResultModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CamporeeScoreBreakdownResultModel(
      camporeeEventId: safeInt(json['camporee_event_id']),
      score: CamporeeOfficialScoreModel.fromJson(json),
    );
  }

  CamporeeScoreBreakdownResult toEntity() => CamporeeScoreBreakdownResult(
        camporeeEventId: camporeeEventId,
        score: score.toEntity(),
      );

  @override
  List<Object?> get props => [camporeeEventId, score];
}
