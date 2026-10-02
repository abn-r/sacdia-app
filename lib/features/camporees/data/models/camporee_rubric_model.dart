import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/camporee_rubric.dart';

/// Modelo de criterio de rúbrica para eventos de camporí.
class CamporeeRubricModel extends Equatable {
  final int rubricId;
  final int eventId;
  final String title;
  final String? description;
  final double maxPoints;
  final int displayOrder;
  final bool active;

  const CamporeeRubricModel({
    required this.rubricId,
    required this.eventId,
    required this.title,
    this.description,
    required this.maxPoints,
    required this.displayOrder,
    required this.active,
  });

  factory CamporeeRubricModel.fromJson(Map<String, dynamic> json) {
    return CamporeeRubricModel(
      rubricId: safeInt(json['camporee_event_rubric_id']),
      eventId: safeInt(json['camporee_event_id']),
      title: safeString(json['title']),
      description: safeStringOrNull(json['description']),
      maxPoints: safeDouble(json['max_points']),
      displayOrder: safeInt(json['display_order']),
      active: safeBool(json['active'], true),
    );
  }

  CamporeeRubric toEntity() {
    return CamporeeRubric(
      rubricId: rubricId,
      eventId: eventId,
      title: title,
      description: description,
      maxPoints: maxPoints,
      displayOrder: displayOrder,
      active: active,
    );
  }

  @override
  List<Object?> get props => [
        rubricId,
        eventId,
        title,
        description,
        maxPoints,
        displayOrder,
        active,
      ];
}

/// Sobre de `GET /camporee-events/:eventId/rubrics`.
class CamporeeEventRubricSheetModel extends Equatable {
  final List<CamporeeRubricModel> rubrics;
  final double minPoints;

  const CamporeeEventRubricSheetModel({
    required this.rubrics,
    this.minPoints = 0,
  });

  factory CamporeeEventRubricSheetModel.fromEnvelope(dynamic responseData) {
    final rawList = responseData is Map && responseData['data'] is List
        ? responseData['data'] as List<dynamic>
        : responseData is List
            ? responseData
            : const <dynamic>[];
    final minPoints = responseData is Map
        ? safeDouble(responseData['min_points'])
        : 0.0;

    return CamporeeEventRubricSheetModel(
      rubrics: rawList
          .whereType<Map>()
          .map(
            (item) => CamporeeRubricModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      minPoints: minPoints,
    );
  }

  CamporeeEventRubricSheet toEntity() {
    return CamporeeEventRubricSheet(
      rubrics: rubrics.map((rubric) => rubric.toEntity()).toList(),
      minPoints: minPoints,
    );
  }

  @override
  List<Object?> get props => [rubrics, minPoints];
}
