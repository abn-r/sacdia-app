import '../../domain/entities/class_requirement.dart';
import 'requirement_evidence_model.dart';

/// Modelo de datos para [ClassRequirement].
class ClassRequirementModel extends ClassRequirement {
  const ClassRequirementModel({
    required super.id,
    required super.name,
    super.description,
    required super.moduleId,
    super.type,
    super.pointValue,
    super.maxFiles,
    required super.status,
    super.files,
    super.submittedByName,
    super.submittedAt,
    super.validatedByName,
    super.validatedAt,
    super.earnedPoints,
    super.linkedHonorId,
    super.linkedHonorName,
    super.linkedHonorCompleted,
  });

  factory ClassRequirementModel.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'] as List<dynamic>? ??
        json['evidence_files'] as List<dynamic>? ??
        [];

    final files = rawFiles
        .map((f) =>
            RequirementEvidenceModel.fromJson(f as Map<String, dynamic>))
        .toList();

    return ClassRequirementModel(
      id: _parseInt(json['id'] ?? json['section_id'] ?? json['requirement_id'] ?? 0),
      name: (json['name'] ?? json['section_name'] ?? '').toString(),
      description: json['description']?.toString(),
      moduleId: _parseInt(json['module_id'] ?? json['moduleId'] ?? 0),
      type: requirementTypeFromString(json['type']?.toString()),
      pointValue: _parseInt(json['point_value'] ?? json['pointValue'] ?? 0),
      maxFiles: _parseInt(json['max_files'] ?? json['maxFiles'] ?? 10),
      status: requirementStatusFromString(json['status']?.toString()),
      files: files,
      submittedByName:
          (json['submitted_by_name'] ?? json['submittedByName'])?.toString(),
      submittedAt: _parseDate(
          json['submitted_at']?.toString() ?? json['submittedAt']?.toString()),
      validatedByName:
          (json['validated_by_name'] ?? json['validatedByName'])?.toString(),
      validatedAt: _parseDate(
          json['validated_at']?.toString() ?? json['validatedAt']?.toString()),
      earnedPoints:
          _parseInt(json['earned_points'] ?? json['earnedPoints'] ?? 0),
      linkedHonorId: json['honor_id'] != null
          ? _parseInt(json['honor_id'])
          : json['linkedHonorId'] != null
              ? _parseInt(json['linkedHonorId'])
              : null,
      linkedHonorName:
          (json['honor_name'] ?? json['linkedHonorName'])?.toString(),
      linkedHonorCompleted: json['honor_completed'] as bool? ??
          json['linkedHonorCompleted'] as bool?,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  ClassRequirement toEntity() => ClassRequirement(
        id: id,
        name: name,
        description: description,
        moduleId: moduleId,
        type: type,
        pointValue: pointValue,
        maxFiles: maxFiles,
        status: status,
        files: files,
        submittedByName: submittedByName,
        submittedAt: submittedAt,
        validatedByName: validatedByName,
        validatedAt: validatedAt,
        earnedPoints: earnedPoints,
        linkedHonorId: linkedHonorId,
        linkedHonorName: linkedHonorName,
        linkedHonorCompleted: linkedHonorCompleted,
      );
}
