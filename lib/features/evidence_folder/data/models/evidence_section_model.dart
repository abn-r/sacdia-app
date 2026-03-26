import '../../domain/entities/evidence_section.dart';
import 'evidence_file_model.dart';

/// Modelo de datos para [EvidenceSection].
class EvidenceSectionModel extends EvidenceSection {
  const EvidenceSectionModel({
    required super.id,
    required super.name,
    super.description,
    required super.pointValue,
    required super.percentage,
    super.maxFiles,
    required super.status,
    super.files,
    super.submittedByName,
    super.submittedAt,
    super.validatedByName,
    super.validatedAt,
    super.earnedPoints,
    super.evaluatedByName,
    super.evaluatedAt,
    super.evaluationNotes,
  });

  factory EvidenceSectionModel.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'] as List<dynamic>? ??
        json['evidence_files'] as List<dynamic>? ??
        [];

    final files = rawFiles
        .map((f) => EvidenceFileModel.fromJson(f as Map<String, dynamic>))
        .toList();

    return EvidenceSectionModel(
      id: (json['id'] ?? json['section_id'] ?? '').toString(),
      name: (json['name'] ?? json['section_name'] ?? '').toString(),
      description: json['description']?.toString(),
      pointValue: _parseInt(json['point_value'] ?? json['pointValue'] ?? 0),
      percentage:
          _parseDouble(json['percentage'] ?? json['weight_percentage'] ?? 0.0),
      maxFiles: _parseInt(json['max_files'] ?? json['maxFiles'] ?? 10),
      status: evidenceSectionStatusFromString(
        json['status']?.toString(),
      ),
      files: files,
      submittedByName: (json['submitted_by_name'] ??
              json['submittedByName'])
          ?.toString(),
      submittedAt: _parseDate(
          json['submitted_at']?.toString() ?? json['submittedAt']?.toString()),
      validatedByName: (json['validated_by_name'] ??
              json['validatedByName'])
          ?.toString(),
      validatedAt: _parseDate(
          json['validated_at']?.toString() ?? json['validatedAt']?.toString()),
      earnedPoints:
          _parseInt(json['earned_points'] ?? json['earnedPoints'] ?? 0),
      evaluatedByName: (json['evaluated_by_name'] ??
              json['evaluatedByName'])
          ?.toString(),
      evaluatedAt: _parseDate(
          json['evaluated_at']?.toString() ?? json['evaluatedAt']?.toString()),
      evaluationNotes: (json['evaluation_notes'] ??
              json['evaluationNotes'])
          ?.toString(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  EvidenceSection toEntity() => EvidenceSection(
        id: id,
        name: name,
        description: description,
        pointValue: pointValue,
        percentage: percentage,
        maxFiles: maxFiles,
        status: status,
        files: files,
        submittedByName: submittedByName,
        submittedAt: submittedAt,
        validatedByName: validatedByName,
        validatedAt: validatedAt,
        earnedPoints: earnedPoints,
        evaluatedByName: evaluatedByName,
        evaluatedAt: evaluatedAt,
        evaluationNotes: evaluationNotes,
      );
}
