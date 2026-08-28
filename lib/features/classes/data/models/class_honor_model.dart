import '../../domain/entities/class_honor.dart';
import '../../../../core/utils/json_helpers.dart';

const String _honorImagesBase =
    'https://sacdia-files.s3.us-east-1.amazonaws.com/Especialidades/';

String? _buildHonorImageUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  return '$_honorImagesBase$raw';
}

/// Modelo de datos para [ClassHonor].
///
/// Parsea la respuesta de `GET /classes/:classId/honors`:
/// `[{ class_honor_id, relation_type, module_id, module_name, honor: {
/// honor_id, name, honor_image, material_url, honors_category_id, skill_level
/// }, user_status }]`.
class ClassHonorModel extends ClassHonor {
  const ClassHonorModel({
    required super.classHonorId,
    required super.relationType,
    required super.honorId,
    required super.honorName,
    super.honorImage,
    super.honorCategoryId,
    super.honorSkillLevel,
    super.moduleId,
    super.moduleName,
    super.materialUrl,
    super.userStatus,
  });

  factory ClassHonorModel.fromJson(Map<String, dynamic> json) {
    final honorJson = json['honor'] as Map<String, dynamic>? ?? const {};

    return ClassHonorModel(
      classHonorId: safeInt(json['class_honor_id']),
      relationType:
          classHonorRelationTypeFromApi(json['relation_type']?.toString()),
      honorId: safeInt(honorJson['honor_id'] ?? json['honor_id']),
      honorName: safeString(honorJson['name']),
      honorImage: _buildHonorImageUrl(
        safeStringOrNull(honorJson['honor_image']),
      ),
      honorCategoryId: safeIntOrNull(honorJson['honors_category_id']),
      honorSkillLevel: safeIntOrNull(honorJson['skill_level']),
      moduleId: safeIntOrNull(json['module_id']),
      moduleName: safeStringOrNull(json['module_name']),
      materialUrl: safeStringOrNull(
        honorJson['material_url'] ?? json['material_url'],
      ),
      userStatus: safeStringOrNull(json['user_status']),
    );
  }

  ClassHonor toEntity() => ClassHonor(
        classHonorId: classHonorId,
        relationType: relationType,
        honorId: honorId,
        honorName: honorName,
        honorImage: honorImage,
        honorCategoryId: honorCategoryId,
        honorSkillLevel: honorSkillLevel,
        moduleId: moduleId,
        moduleName: moduleName,
        materialUrl: materialUrl,
        userStatus: userStatus,
      );
}
