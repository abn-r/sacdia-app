import 'package:equatable/equatable.dart';

import 'member_ranking.dart';

/// Domain entity for a section ranking row.
class SectionRanking extends Equatable {
  final int clubSectionId;
  final String sectionName;
  final double? compositeScorePct;
  final int? rankPosition;
  final int activeEnrollmentCount;
  final AwardCategory? awardedCategory;
  final DateTime? compositeCalculatedAt;

  const SectionRanking({
    required this.clubSectionId,
    required this.sectionName,
    this.compositeScorePct,
    this.rankPosition,
    required this.activeEnrollmentCount,
    this.awardedCategory,
    this.compositeCalculatedAt,
  });

  @override
  List<Object?> get props => [
        clubSectionId,
        sectionName,
        compositeScorePct,
        rankPosition,
        activeEnrollmentCount,
        awardedCategory,
        compositeCalculatedAt,
      ];
}

/// Domain entity for a member inside a section ranking drill-down.
/// Reuses [MemberRanking] — director sees real names (RBAC enforced server-side).
typedef SectionMember = MemberRanking;
