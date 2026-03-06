import 'package:equatable/equatable.dart';

/// Modelo para tipos de actividad del catálogo del sistema.
class ActivityTypeModel extends Equatable {
  final int activityTypeId;
  final String code;
  final String name;
  final String? description;

  const ActivityTypeModel({
    required this.activityTypeId,
    required this.code,
    required this.name,
    this.description,
  });

  factory ActivityTypeModel.fromJson(Map<String, dynamic> json) {
    return ActivityTypeModel(
      activityTypeId: json['activity_type_id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activity_type_id': activityTypeId,
      'code': code,
      'name': name,
      'description': description,
    };
  }

  @override
  List<Object?> get props => [activityTypeId, code, name, description];
}
