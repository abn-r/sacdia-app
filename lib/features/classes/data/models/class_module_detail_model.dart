import '../../domain/entities/class_module_detail.dart';
import 'class_requirement_model.dart';
import '../../../../core/utils/json_helpers.dart';

/// Modelo de datos para [ClassModuleDetail].
class ClassModuleDetailModel extends ClassModuleDetail {
  const ClassModuleDetailModel({
    required super.id,
    required super.name,
    super.description,
    required super.classId,
    super.requirements,
  });

  factory ClassModuleDetailModel.fromJson(Map<String, dynamic> json) {
    final rawRequirements = json['sections'] as List<dynamic>? ??
        json['requirements'] as List<dynamic>? ??
        [];

    final requirements = rawRequirements
        .map((r) =>
            ClassRequirementModel.fromJson(r as Map<String, dynamic>).toEntity())
        .toList();

    return ClassModuleDetailModel(
      id: safeInt(json['id'] ?? json['module_id']),
      name: safeString(json['name'] ?? json['module_name']),
      description: json['description']?.toString(),
      classId: safeInt(json['class_id'] ?? json['classId']),
      requirements: requirements,
    );
  }

  ClassModuleDetail toEntity() => ClassModuleDetail(
        id: id,
        name: name,
        description: description,
        classId: classId,
        requirements: requirements,
      );
}
