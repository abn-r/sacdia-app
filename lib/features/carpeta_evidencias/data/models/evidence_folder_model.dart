import '../../domain/entities/evidence_folder.dart';
import 'evidence_section_model.dart';

/// Modelo de datos para [EvidenceFolder].
class EvidenceFolderModel extends EvidenceFolder {
  const EvidenceFolderModel({
    required super.id,
    required super.name,
    super.description,
    required super.isOpen,
    required super.totalPoints,
    required super.totalPercentage,
    required super.sections,
  });

  factory EvidenceFolderModel.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? [];
    final sections = rawSections
        .map((s) =>
            EvidenceSectionModel.fromJson(s as Map<String, dynamic>).toEntity())
        .toList();

    return EvidenceFolderModel(
      id: (json['id'] ?? json['folder_id'] ?? '').toString(),
      name: (json['name'] ?? json['folder_name'] ?? 'Carpeta de Evidencias')
          .toString(),
      description: json['description']?.toString(),
      isOpen: json['is_open'] as bool? ?? json['isOpen'] as bool? ?? true,
      totalPoints: _parseInt(json['total_points'] ?? json['totalPoints'] ?? 0),
      totalPercentage:
          _parseDouble(json['total_percentage'] ?? json['totalPercentage'] ?? 0),
      sections: sections,
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

  EvidenceFolder toEntity() => EvidenceFolder(
        id: id,
        name: name,
        description: description,
        isOpen: isOpen,
        totalPoints: totalPoints,
        totalPercentage: totalPercentage,
        sections: sections,
      );
}
