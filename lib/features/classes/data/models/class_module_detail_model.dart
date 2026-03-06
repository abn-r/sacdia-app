import '../../domain/entities/class_module_detail.dart';
import 'class_requirement_model.dart';

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
      id: (json['id'] ?? json['module_id'] ?? 0) as int,
      name: (json['name'] ?? json['module_name'] ?? '').toString(),
      description: json['description']?.toString(),
      classId: (json['class_id'] ?? json['classId'] ?? 0) as int,
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
