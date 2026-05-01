import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/award_tier.dart';
import '../../domain/entities/member_breakdown.dart';
import 'member_ranking_dto.dart';

/// DTO for [ClassBreakdown] — mirrors [ClassBreakdownDto] from the backend.
class ClassBreakdownDtoModel {
  final int completedSections;
  final int requiredSections;
  final String? folderStatus;

  const ClassBreakdownDtoModel({
    required this.completedSections,
    required this.requiredSections,
    this.folderStatus,
  });

  factory ClassBreakdownDtoModel.fromJson(Map<String, dynamic> json) {
    return ClassBreakdownDtoModel(
      completedSections: safeInt(json['completed_sections']),
      requiredSections: safeInt(json['required_sections']),
      folderStatus: safeStringOrNull(json['folder_status']),
    );
  }

  ClassBreakdown toEntity() {
    return ClassBreakdown(
      completedSections: completedSections,
      requiredSections: requiredSections,
      folderStatus: folderStatus,
    );
  }
}

/// DTO for [InvestitureBreakdown] — mirrors [InvestitureBreakdownDto].
class InvestitureBreakdownDtoModel {
  final String? status;

  const InvestitureBreakdownDtoModel({this.status});

  factory InvestitureBreakdownDtoModel.fromJson(Map<String, dynamic> json) {
    return InvestitureBreakdownDtoModel(
      status: safeStringOrNull(json['status']),
    );
  }

  InvestitureBreakdown toEntity() {
    return InvestitureBreakdown(status: status);
  }
}

/// DTO for [CamporeeBreakdown] — mirrors [CamporeeBreakdownDto].
class CamporeeBreakdownDtoModel {
  final bool participated;
  final int? totalCamporees;

  const CamporeeBreakdownDtoModel({
    required this.participated,
    this.totalCamporees,
  });

  factory CamporeeBreakdownDtoModel.fromJson(Map<String, dynamic> json) {
    return CamporeeBreakdownDtoModel(
      participated: (json['participated'] as bool?) ?? false,
      totalCamporees: safeIntOrNull(json['total_camporees']),
    );
  }

  CamporeeBreakdown toEntity() {
    return CamporeeBreakdown(
      participated: participated,
      totalCamporees: totalCamporees,
    );
  }
}

/// DTO for [BreakdownWeights] — mirrors [WeightsBreakdownDto].
///
/// Accepts both `weights` and `weights_applied` as root keys for forward
/// compatibility (admin normalizer pattern).
class BreakdownWeightsDtoModel {
  final int classPct;
  final int investiturePct;
  final int camporeePct;
  final String source;

  const BreakdownWeightsDtoModel({
    required this.classPct,
    required this.investiturePct,
    required this.camporeePct,
    required this.source,
  });

  factory BreakdownWeightsDtoModel.fromJson(Map<String, dynamic> json) {
    return BreakdownWeightsDtoModel(
      classPct: safeInt(json['class_pct']),
      investiturePct: safeInt(json['investiture_pct']),
      camporeePct: safeInt(json['camporee_pct']),
      source: safeString(json['source'], 'global-default'),
    );
  }

  BreakdownWeights toEntity() {
    return BreakdownWeights(
      classPct: classPct,
      investiturePct: investiturePct,
      camporeePct: camporeePct,
      source: source,
    );
  }
}

/// DTO for the full breakdown response from
/// `GET /member-rankings/:enrollmentId/breakdown?year_id=N`.
///
/// Extends [MemberRankingDto] fields (snake_case mirrors [MemberBreakdownDto]
/// from the backend) with the four breakdown sub-objects.
///
/// Field-naming flexibility:
/// - The weights object may arrive under `weights` or `weights_applied` —
///   both keys are checked in `fromJson` to handle future API evolution.
class MemberBreakdownDtoModel {
  // ── Core fields (from MemberRankingResponseDto) ────────────────────────────
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

  // ── Breakdown fields ───────────────────────────────────────────────────────
  final ClassBreakdownDtoModel classBreakdown;
  final InvestitureBreakdownDtoModel investitureBreakdown;
  final CamporeeBreakdownDtoModel camporeeBreakdown;
  final BreakdownWeightsDtoModel weights;

  const MemberBreakdownDtoModel({
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
    required this.classBreakdown,
    required this.investitureBreakdown,
    required this.camporeeBreakdown,
    required this.weights,
  });

  factory MemberBreakdownDtoModel.fromJson(Map<String, dynamic> json) {
    // Accept both `weights` and `weights_applied` for forward compatibility.
    final rawWeights = (json['weights'] ?? json['weights_applied'])
        as Map<String, dynamic>?;

    return MemberBreakdownDtoModel(
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
      classBreakdown: ClassBreakdownDtoModel.fromJson(
        json['class_breakdown'] as Map<String, dynamic>? ?? {},
      ),
      investitureBreakdown: InvestitureBreakdownDtoModel.fromJson(
        json['investiture_breakdown'] as Map<String, dynamic>? ?? {},
      ),
      camporeeBreakdown: CamporeeBreakdownDtoModel.fromJson(
        json['camporee_breakdown'] as Map<String, dynamic>? ?? {},
      ),
      weights: rawWeights != null
          ? BreakdownWeightsDtoModel.fromJson(rawWeights)
          : const BreakdownWeightsDtoModel(
              classPct: 50,
              investiturePct: 30,
              camporeePct: 20,
              source: 'global-default',
            ),
    );
  }

  MemberBreakdown toEntity() {
    return MemberBreakdown(
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
      classBreakdown: classBreakdown.toEntity(),
      investitureBreakdown: investitureBreakdown.toEntity(),
      camporeeBreakdown: camporeeBreakdown.toEntity(),
      weights: weights.toEntity(),
    );
  }
}
