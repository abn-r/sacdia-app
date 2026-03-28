import '../../domain/entities/class_with_progress.dart';
import 'class_module_detail_model.dart';
import '../../../../core/utils/json_helpers.dart';

/// Modelo de datos para [ClassWithProgress].
class ClassWithProgressModel extends ClassWithProgress {
  const ClassWithProgressModel({
    required super.id,
    required super.name,
    super.description,
    required super.clubTypeId,
    super.imageUrl,
    super.modules,
  });

  factory ClassWithProgressModel.fromJson(Map<String, dynamic> json) {
    final rawModules = json['modules'] as List<dynamic>? ?? [];

    final modules = rawModules
        .map((m) =>
            ClassModuleDetailModel.fromJson(m as Map<String, dynamic>).toEntity())
        .toList();

    return ClassWithProgressModel(
      id: safeInt(json['class_id'] ?? json['id']),
      name: safeString(json['name'], 'Clase'),
      description: json['description']?.toString(),
      clubTypeId: safeInt(json['club_type_id'] ?? json['clubTypeId']),
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
      modules: modules,
    );
  }

  ClassWithProgress toEntity() => ClassWithProgress(
        id: id,
        name: name,
        description: description,
        clubTypeId: clubTypeId,
        imageUrl: imageUrl,
        modules: modules,
      );
}
