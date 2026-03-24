import 'package:equatable/equatable.dart';
import '../../domain/entities/annual_folder.dart';

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
      id: (json['id'] ?? json['evidence_id']) as int,
      folderId: json['folder_id'] as int? ?? 0,
      sectionId: json['section_id'] as int? ?? 0,
      fileUrl: json['file_url'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      notes: json['notes'] as String?,
      uploadedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
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
      id: (json['id'] ?? json['section_id']) as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
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
      id: (json['id'] ?? json['folder_id']) as int,
      enrollmentId: json['enrollment_id'] as int? ?? 0,
      year: json['year'] as int? ?? DateTime.now().year,
      status: json['status'] as String? ?? 'open',
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
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
