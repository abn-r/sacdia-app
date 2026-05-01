import 'package:equatable/equatable.dart';

import 'award_tier.dart';
import 'member_ranking.dart';

/// Breakdown detail for the class signal component.
class ClassBreakdown extends Equatable {
  final int completedSections;
  final int requiredSections;
  final String? folderStatus;

  const ClassBreakdown({
    required this.completedSections,
    required this.requiredSections,
    this.folderStatus,
  });

  @override
  List<Object?> get props =>
      [completedSections, requiredSections, folderStatus];
}

/// Breakdown detail for the investiture signal component.
class InvestitureBreakdown extends Equatable {
  final String? status;

  const InvestitureBreakdown({this.status});

  @override
  List<Object?> get props => [status];
}

/// Breakdown detail for the camporee signal component.
class CamporeeBreakdown extends Equatable {
  final bool participated;
  final int? totalCamporees;

  const CamporeeBreakdown({
    required this.participated,
    this.totalCamporees,
  });

  @override
  List<Object?> get props => [participated, totalCamporees];
}

/// Applied weights for the composite score formula.
class BreakdownWeights extends Equatable {
  final int classPct;
  final int investiturePct;
  final int camporeePct;

  /// Describes where these weights came from (e.g. 'global-default', 'club-custom').
  final String source;

  const BreakdownWeights({
    required this.classPct,
    required this.investiturePct,
    required this.camporeePct,
    required this.source,
  });

  @override
  List<Object?> get props => [classPct, investiturePct, camporeePct, source];
}

/// Full breakdown of a member's ranking — returned by
/// `GET /member-rankings/:enrollmentId/breakdown?year_id=N`.
///
/// Extends the base [MemberRanking] fields with per-signal detail and weights.
class MemberBreakdown extends Equatable {
  // ── Core ranking fields (mirrors MemberRanking) ────────────────────────────
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

  // ── Breakdown-specific fields ──────────────────────────────────────────────
  final ClassBreakdown classBreakdown;
  final InvestitureBreakdown investitureBreakdown;
  final CamporeeBreakdown camporeeBreakdown;
  final BreakdownWeights weights;

  const MemberBreakdown({
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
        classBreakdown,
        investitureBreakdown,
        camporeeBreakdown,
        weights,
      ];
}
