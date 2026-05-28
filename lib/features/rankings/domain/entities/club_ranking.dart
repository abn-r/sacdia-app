import 'package:equatable/equatable.dart';

/// Institutional club ranking row.
///
/// This ranks clubs by club type within the caller's authorized hierarchy
/// scope, using the annual-folder composite score.
class ClubRanking extends Equatable {
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

  const ClubRanking({
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

  @override
  List<Object?> get props => [
        rankPosition,
        clubEnrollmentId,
        ecclesiasticalYearId,
        localFieldId,
        clubName,
        totalEarnedPoints,
        totalMaxPoints,
        progressPercentage,
        awardCategoryName,
        folderScorePct,
        financeScorePct,
        camporeeScorePct,
        evidenceScorePct,
        compositeScorePct,
        compositeCalculatedAt,
      ];
}
