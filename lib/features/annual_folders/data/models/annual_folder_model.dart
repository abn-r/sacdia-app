import 'package:equatable/equatable.dart';
import '../../domain/entities/annual_folder.dart';
import '../../../../core/utils/json_helpers.dart';

/// Modelo de evidencia de la carpeta anual
class FolderEvidenceModel extends Equatable {
  final int id;
  final int folderId;
  final int sectionId;
  final String fileUrl;
  final String fileName;
  final String? notes;
  final DateTime? uploadedAt;

  const FolderEvidenceModel({
    required this.id,
    required this.folderId,
    required this.sectionId,
    required this.fileUrl,
    required this.fileName,
    this.notes,
    this.uploadedAt,
  });

  factory FolderEvidenceModel.fromJson(Map<String, dynamic> json) {
    return FolderEvidenceModel(
      id: safeInt(json['id'] ?? json['evidence_id']),
      folderId: safeInt(json['folder_id']),
      sectionId: safeInt(json['section_id']),
      fileUrl: safeString(json['file_url']),
      fileName: safeString(json['file_name']),
      notes: safeStringOrNull(json['notes']),
      uploadedAt: json['created_at'] != null
          ? DateTime.tryParse(safeString(json['created_at']))
          : null,
    );
  }

  FolderEvidence toEntity() {
    return FolderEvidence(
      id: id,
      folderId: folderId,
      sectionId: sectionId,
      fileUrl: fileUrl,
      fileName: fileName,
      notes: notes,
      uploadedAt: uploadedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, folderId, sectionId, fileUrl, fileName, notes, uploadedAt];
}

/// Modelo de sección de la carpeta anual
class FolderSectionModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final List<FolderEvidenceModel> evidences;

  const FolderSectionModel({
    required this.id,
    required this.name,
    this.description,
    required this.evidences,
  });

  factory FolderSectionModel.fromJson(Map<String, dynamic> json) {
    final rawEvidences = json['evidences'] as List<dynamic>? ?? [];
    return FolderSectionModel(
      id: safeInt(json['id'] ?? json['section_id']),
      name: safeString(json['name']),
      description: safeStringOrNull(json['description']),
      evidences: rawEvidences
          .map((e) => FolderEvidenceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  FolderSection toEntity() {
    return FolderSection(
      id: id,
      name: name,
      description: description,
      evidences: evidences.map((e) => e.toEntity()).toList(),
    );
  }

  @override
  List<Object?> get props => [id, name, description, evidences];
}

/// Modelo de la carpeta anual
class AnnualFolderModel extends Equatable {
  final int id;
  final int enrollmentId;
  final int year;
  final String status;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final List<FolderSectionModel> sections;

  const AnnualFolderModel({
    required this.id,
    required this.enrollmentId,
    required this.year,
    required this.status,
    this.submittedAt,
    this.createdAt,
    required this.sections,
  });

  factory AnnualFolderModel.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? [];
    return AnnualFolderModel(
      id: safeInt(json['id'] ?? json['folder_id']),
      enrollmentId: safeInt(json['enrollment_id']),
      year: safeInt(json['year'], DateTime.now().year),
      status: safeString(json['status'], 'open'),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(safeString(json['submitted_at']))
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(safeString(json['created_at']))
          : null,
      sections: rawSections
          .map((s) => FolderSectionModel.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  AnnualFolder toEntity() {
    return AnnualFolder(
      id: id,
      enrollmentId: enrollmentId,
      year: year,
      status: status,
      submittedAt: submittedAt,
      createdAt: createdAt,
      sections: sections.map((s) => s.toEntity()).toList(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        enrollmentId,
        year,
        status,
        submittedAt,
        createdAt,
        sections,
      ];
}
