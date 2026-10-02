import 'package:equatable/equatable.dart';

/// Puntaje oficial ya registrado para un evento y una sección.
class CamporeeOfficialScore extends Equatable {
  final String resultId;
  final String scoreStatus;
  final bool isNoShow;
  final double totalAwarded;
  final double totalMax;
  final double rawAwarded;
  final double minimumAdjustment;
  final String? notes;
  final String evaluatorName;
  final DateTime? submittedAt;
  final List<CamporeeOfficialScoreItem> items;

  const CamporeeOfficialScore({
    required this.resultId,
    required this.scoreStatus,
    required this.isNoShow,
    required this.totalAwarded,
    required this.totalMax,
    required this.rawAwarded,
    required this.minimumAdjustment,
    this.notes,
    required this.evaluatorName,
    this.submittedAt,
    required this.items,
  });

  @override
  List<Object?> get props => [
        resultId,
        scoreStatus,
        isNoShow,
        totalAwarded,
        totalMax,
        rawAwarded,
        minimumAdjustment,
        notes,
        evaluatorName,
        submittedAt,
        items,
      ];
}

class CamporeeOfficialScoreItem extends Equatable {
  final int rubricId;
  final String title;
  final double awardedPoints;
  final double maxPoints;

  const CamporeeOfficialScoreItem({
    required this.rubricId,
    required this.title,
    required this.awardedPoints,
    required this.maxPoints,
  });

  @override
  List<Object?> get props => [rubricId, title, awardedPoints, maxPoints];
}
