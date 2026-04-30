import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/member_ranking.dart';

/// DTO for an award category embedded in ranking responses.
class AwardedCategoryDto {
  final String id;
  final String name;
  final String? icon;
  final double minPct;
  final double maxPct;

  const AwardedCategoryDto({
    required this.id,
    required this.name,
    this.icon,
    required this.minPct,
    required this.maxPct,
  });

  factory AwardedCategoryDto.fromJson(Map<String, dynamic> json) {
    return AwardedCategoryDto(
      id: safeString(json['id']),
      name: safeString(json['name']),
      icon: safeStringOrNull(json['icon']),
      minPct: (json['min_pct'] as num?)?.toDouble() ?? 0.0,
      maxPct: (json['max_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  AwardCategory toEntity() {
    return AwardCategory(
      id: id,
      name: name,
      icon: icon,
      minPct: minPct,
      maxPct: maxPct,
    );
  }
}

/// DTO for a single member ranking row — mirrors [MemberRankingResponseDto].
class MemberRankingDto {
  final int enrollmentId;
  final String userId;
  final String memberName;
  final int? clubSectionId;
  final String? sectionName;
  final double? classScorePct;
  final double? investitureScorePct;
  final double? camporeeScorePct;
  final double? compositeScorePct;
  final int? rankPosition;
  final AwardedCategoryDto? awardedCategory;
  final DateTime? compositeCalculatedAt;

  const MemberRankingDto({
    required this.enrollmentId,
    required this.userId,
    required this.memberName,
    this.clubSectionId,
    this.sectionName,
    this.classScorePct,
    this.investitureScorePct,
    this.camporeeScorePct,
    this.compositeScorePct,
    this.rankPosition,
    this.awardedCategory,
    this.compositeCalculatedAt,
  });

  factory MemberRankingDto.fromJson(Map<String, dynamic> json) {
    return MemberRankingDto(
      enrollmentId: safeInt(json['enrollment_id']),
      userId: safeString(json['user_id']),
      memberName: safeString(json['member_name']),
      clubSectionId: safeIntOrNull(json['club_section_id']),
      sectionName: safeStringOrNull(json['section_name']),
      classScorePct: (json['class_score_pct'] as num?)?.toDouble(),
      investitureScorePct:
          (json['investiture_score_pct'] as num?)?.toDouble(),
      camporeeScorePct: (json['camporee_score_pct'] as num?)?.toDouble(),
      compositeScorePct: (json['composite_score_pct'] as num?)?.toDouble(),
      rankPosition: safeIntOrNull(json['rank_position']),
      awardedCategory: json['awarded_category'] != null
          ? AwardedCategoryDto.fromJson(
              json['awarded_category'] as Map<String, dynamic>)
          : null,
      compositeCalculatedAt: json['composite_calculated_at'] != null
          ? DateTime.tryParse(safeString(json['composite_calculated_at']))
          : null,
    );
  }

  MemberRanking toEntity() {
    return MemberRanking(
      enrollmentId: enrollmentId,
      userId: userId,
      memberName: memberName,
      clubSectionId: clubSectionId,
      sectionName: sectionName,
      classScorePct: classScorePct,
      investitureScorePct: investitureScorePct,
      camporeeScorePct: camporeeScorePct,
      compositeScorePct: compositeScorePct,
      rankPosition: rankPosition,
      awardedCategory: awardedCategory?.toEntity(),
      compositeCalculatedAt: compositeCalculatedAt,
    );
  }
}

/// DTO for an anonymized top-N peer entry — mirrors [AnonymizedTopNEntryDto].
class AnonymizedTopNEntryDto {
  /// Backend sends privacy-safe label: "Miembro #N".
  final String memberName;
  final double? compositeScorePct;
  final int? rankPosition;

  const AnonymizedTopNEntryDto({
    required this.memberName,
    this.compositeScorePct,
    this.rankPosition,
  });

  factory AnonymizedTopNEntryDto.fromJson(Map<String, dynamic> json) {
    return AnonymizedTopNEntryDto(
      memberName: safeString(json['member_name']),
      compositeScorePct: (json['composite_score_pct'] as num?)?.toDouble(),
      rankPosition: safeIntOrNull(json['rank_position']),
    );
  }

  AnonymizedTopNEntry toEntity() {
    return AnonymizedTopNEntry(
      memberName: memberName,
      compositeScorePct: compositeScorePct,
      rankPosition: rankPosition,
    );
  }
}

/// DTO for `GET /member-rankings/me` response — mirrors [MemberMyRankingDto].
class MyRankingResponseDto {
  final MemberRankingDto? member;
  final String visibilityMode;
  final List<AnonymizedTopNEntryDto>? topN;

  const MyRankingResponseDto({
    required this.member,
    required this.visibilityMode,
    this.topN,
  });

  factory MyRankingResponseDto.fromJson(Map<String, dynamic> json) {
    final rawTopN = json['top_n'] as List<dynamic>?;
    return MyRankingResponseDto(
      member: json['member'] != null
          ? MemberRankingDto.fromJson(json['member'] as Map<String, dynamic>)
          : null,
      visibilityMode: safeString(json['visibility_mode'], 'hidden'),
      topN: rawTopN
          ?.map((e) =>
              AnonymizedTopNEntryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  MyRankingView toEntity() {
    return MyRankingView(
      member: member?.toEntity(),
      visibilityMode:
          MyRankingVisibilityMode.fromString(visibilityMode),
      topN: topN?.map((e) => e.toEntity()).toList(),
    );
  }
}
