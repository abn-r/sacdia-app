import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/camporee_official_score.dart';

class CamporeeOfficialScoreModel extends Equatable {
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
  final List<CamporeeOfficialScoreItemModel> items;

  const CamporeeOfficialScoreModel({
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

  factory CamporeeOfficialScoreModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (item) => CamporeeOfficialScoreItemModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <CamporeeOfficialScoreItemModel>[];
    final submittedRaw = json['submitted_at']?.toString();

    return CamporeeOfficialScoreModel(
      resultId: safeString(json['camporee_event_section_result_id']),
      scoreStatus: safeString(json['score_status']),
      isNoShow: safeBool(json['is_no_show']),
      totalAwarded: safeDouble(json['total_awarded_points']),
      totalMax: safeDouble(json['total_max_points']),
      rawAwarded: safeDouble(json['raw_awarded_points']),
      minimumAdjustment: safeDouble(json['minimum_adjustment_points']),
      notes: safeStringOrNull(json['notes']),
      evaluatorName: safeString(json['evaluator_name']),
      submittedAt:
          submittedRaw == null ? null : DateTime.tryParse(submittedRaw),
      items: items,
    );
  }

  CamporeeOfficialScore toEntity() {
    return CamporeeOfficialScore(
      resultId: resultId,
      scoreStatus: scoreStatus,
      isNoShow: isNoShow,
      totalAwarded: totalAwarded,
      totalMax: totalMax,
      rawAwarded: rawAwarded,
      minimumAdjustment: minimumAdjustment,
      notes: notes,
      evaluatorName: evaluatorName,
      submittedAt: submittedAt,
      items: items.map((item) => item.toEntity()).toList(),
    );
  }

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

class CamporeeOfficialScoreItemModel extends Equatable {
  final int rubricId;
  final String title;
  final double awardedPoints;
  final double maxPoints;

  const CamporeeOfficialScoreItemModel({
    required this.rubricId,
    required this.title,
    required this.awardedPoints,
    required this.maxPoints,
  });

  factory CamporeeOfficialScoreItemModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOfficialScoreItemModel(
      rubricId: safeInt(json['camporee_event_rubric_id']),
      title: safeString(json['title']),
      awardedPoints: safeDouble(json['awarded_points']),
      maxPoints: safeDouble(json['max_points']),
    );
  }

  CamporeeOfficialScoreItem toEntity() {
    return CamporeeOfficialScoreItem(
      rubricId: rubricId,
      title: title,
      awardedPoints: awardedPoints,
      maxPoints: maxPoints,
    );
  }

  @override
  List<Object?> get props => [rubricId, title, awardedPoints, maxPoints];
}
