import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/section_ranking.dart';
import 'member_ranking_dto.dart';

/// DTO for a section ranking row — mirrors [SectionRankingResponseDto].
class SectionRankingDto {
  final int clubSectionId;
  final String sectionName;
  final double? compositeScorePct;
  final int? rankPosition;
  final int activeEnrollmentCount;
  final AwardedCategoryDto? awardedCategory;
  final DateTime? compositeCalculatedAt;

  const SectionRankingDto({
    required this.clubSectionId,
    required this.sectionName,
    this.compositeScorePct,
    this.rankPosition,
    required this.activeEnrollmentCount,
    this.awardedCategory,
    this.compositeCalculatedAt,
  });

  factory SectionRankingDto.fromJson(Map<String, dynamic> json) {
    return SectionRankingDto(
      clubSectionId: safeInt(json['club_section_id']),
      sectionName: safeString(json['section_name']),
      compositeScorePct: (json['composite_score_pct'] as num?)?.toDouble(),
      rankPosition: safeIntOrNull(json['rank_position']),
      activeEnrollmentCount: safeInt(json['active_enrollment_count']),
      awardedCategory: json['awarded_category'] != null
          ? AwardedCategoryDto.fromJson(
              json['awarded_category'] as Map<String, dynamic>)
          : null,
      compositeCalculatedAt: json['composite_calculated_at'] != null
          ? DateTime.tryParse(safeString(json['composite_calculated_at']))
          : null,
    );
  }

  SectionRanking toEntity() {
    return SectionRanking(
      clubSectionId: clubSectionId,
      sectionName: sectionName,
      compositeScorePct: compositeScorePct,
      rankPosition: rankPosition,
      activeEnrollmentCount: activeEnrollmentCount,
      awardedCategory: awardedCategory?.toEntity(),
      compositeCalculatedAt: compositeCalculatedAt,
    );
  }
}

/// DTO for a member within a section drill-down.
/// Reuses [MemberRankingDto] since the backend returns [MemberRankingResponseDto]
/// for both `GET /section-rankings/:id/members` and `GET /member-rankings`.
typedef SectionMemberDto = MemberRankingDto;
