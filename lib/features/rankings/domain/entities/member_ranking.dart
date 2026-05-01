import 'package:equatable/equatable.dart';

import 'award_tier.dart';

/// Visibility mode for member rankings — mirrors backend VisibilityMode type.
enum MyRankingVisibilityMode {
  hidden,
  selfOnly,
  selfAndTopN;

  static MyRankingVisibilityMode fromString(String raw) {
    switch (raw) {
      case 'self_only':
        return MyRankingVisibilityMode.selfOnly;
      case 'self_and_top_n':
        return MyRankingVisibilityMode.selfAndTopN;
      default:
        return MyRankingVisibilityMode.hidden;
    }
  }
}

/// Domain entity for an award category assigned to a ranking row.
class AwardCategory extends Equatable {
  final String id;
  final String name;
  final String? icon;
  final double minPct;
  final double maxPct;

  /// Tier de la categoría — expuesto por el backend desde la fase B.
  /// [AwardTier.unknown] cuando el campo no está presente o no es reconocido.
  final AwardTier tier;

  const AwardCategory({
    required this.id,
    required this.name,
    this.icon,
    required this.minPct,
    required this.maxPct,
    this.tier = AwardTier.unknown,
  });

  @override
  List<Object?> get props => [id, name, icon, minPct, maxPct, tier];
}

/// Domain entity for a single member ranking row.
class MemberRanking extends Equatable {
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
  final AwardCategory? awardedCategory;
  final DateTime? compositeCalculatedAt;

  const MemberRanking({
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

  @override
  List<Object?> get props => [
        enrollmentId,
        userId,
        memberName,
        clubSectionId,
        sectionName,
        classScorePct,
        investitureScorePct,
        camporeeScorePct,
        compositeScorePct,
        rankPosition,
        awardedCategory,
        compositeCalculatedAt,
      ];
}

/// Anonymized top-N peer entry visible when visibility_mode = self_and_top_n.
class AnonymizedTopNEntry extends Equatable {
  /// Backend sends "Miembro #N" (privacy-safe label).
  final String memberName;
  final double? compositeScorePct;
  final int? rankPosition;

  const AnonymizedTopNEntry({
    required this.memberName,
    this.compositeScorePct,
    this.rankPosition,
  });

  @override
  List<Object?> get props => [memberName, compositeScorePct, rankPosition];
}

/// Aggregate view returned for `GET /member-rankings/me`.
/// Bundles the member's own row + optional top-N + visibility mode.
/// [member] is null when the score hasn't been calculated yet.
class MyRankingView extends Equatable {
  final MemberRanking? member;
  final MyRankingVisibilityMode visibilityMode;
  final List<AnonymizedTopNEntry>? topN;

  const MyRankingView({
    required this.member,
    required this.visibilityMode,
    this.topN,
  });

  @override
  List<Object?> get props => [member, visibilityMode, topN];
}
