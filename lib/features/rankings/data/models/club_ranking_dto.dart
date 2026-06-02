import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/club_ranking.dart';

class ClubRankingDto {
  final int? rankPosition;
  final String clubEnrollmentId;
  final int ecclesiasticalYearId;
  final int? localFieldId;
  final String clubName;
  final double totalEarnedPoints;
  final double totalMaxPoints;
  final double progressPercentage;
  final String? awardCategoryName;
  final double folderScorePct;
  final double financeScorePct;
  final double camporeeScorePct;
  final double evidenceScorePct;
  final double compositeScorePct;
  final DateTime? compositeCalculatedAt;

  const ClubRankingDto({
    required this.rankPosition,
    required this.clubEnrollmentId,
    required this.ecclesiasticalYearId,
    required this.localFieldId,
    required this.clubName,
    required this.totalEarnedPoints,
    required this.totalMaxPoints,
    required this.progressPercentage,
    required this.awardCategoryName,
    required this.folderScorePct,
    required this.financeScorePct,
    required this.camporeeScorePct,
    required this.evidenceScorePct,
    required this.compositeScorePct,
    required this.compositeCalculatedAt,
  });

  factory ClubRankingDto.fromJson(Map<String, dynamic> json) {
    return ClubRankingDto(
      rankPosition: safeIntOrNull(json['rank_position']),
      clubEnrollmentId: safeString(json['club_enrollment_id']),
      ecclesiasticalYearId: safeInt(json['ecclesiastical_year_id']),
      localFieldId: safeIntOrNull(json['local_field_id']),
      clubName: safeString(json['club_name']),
      totalEarnedPoints: safeDouble(json['total_earned_points']),
      totalMaxPoints: safeDouble(json['total_max_points']),
      progressPercentage: safeDouble(json['progress_percentage']),
      awardCategoryName: safeStringOrNull(json['award_category_name']),
      folderScorePct: safeDouble(json['folder_score_pct']),
      financeScorePct: safeDouble(json['finance_score_pct']),
      camporeeScorePct: safeDouble(json['camporee_score_pct']),
      evidenceScorePct: safeDouble(json['evidence_score_pct']),
      compositeScorePct: safeDouble(json['composite_score_pct']),
      compositeCalculatedAt: json['composite_calculated_at'] != null
          ? DateTime.tryParse(safeString(json['composite_calculated_at']))
          : null,
    );
  }

  ClubRanking toEntity() {
    return ClubRanking(
      rankPosition: rankPosition,
      clubEnrollmentId: clubEnrollmentId,
      ecclesiasticalYearId: ecclesiasticalYearId,
      localFieldId: localFieldId,
      clubName: clubName,
      totalEarnedPoints: totalEarnedPoints,
      totalMaxPoints: totalMaxPoints,
      progressPercentage: progressPercentage,
      awardCategoryName: awardCategoryName,
      folderScorePct: folderScorePct,
      financeScorePct: financeScorePct,
      camporeeScorePct: camporeeScorePct,
      evidenceScorePct: evidenceScorePct,
      compositeScorePct: compositeScorePct,
      compositeCalculatedAt: compositeCalculatedAt,
    );
  }
}
