import 'package:equatable/equatable.dart';

/// Estado de la carpeta anual
enum AnnualFolderStatus { open, submitted, closed }

extension AnnualFolderStatusX on AnnualFolderStatus {
  String get label {
    switch (this) {
      case AnnualFolderStatus.open:
        return 'Abierta';
      case AnnualFolderStatus.submitted:
        return 'Enviada';
      case AnnualFolderStatus.closed:
        return 'Cerrada';
    }
  }

  String get slug {
    switch (this) {
      case AnnualFolderStatus.open:
        return 'open';
      case AnnualFolderStatus.submitted:
        return 'submitted';
      case AnnualFolderStatus.closed:
        return 'closed';
    }
  }
}

/// Evidencia de una sección de la carpeta anual
class FolderEvidence extends Equatable {
  final int id;
  final int folderId;
  final int sectionId;
  final String fileUrl;
  final String fileName;
  final String? notes;
  final DateTime? uploadedAt;

  const FolderEvidence({
    required this.id,
    required this.folderId,
    required this.sectionId,
    required this.fileUrl,
    required this.fileName,
    this.notes,
    this.uploadedAt,
  });

  @override
  List<Object?> get props =>
      [id, folderId, sectionId, fileUrl, fileName, notes, uploadedAt];
}

/// Sección de la carpeta anual con evidencias
class FolderSection extends Equatable {
  final int id;
  final String name;
  final String? description;
  final List<FolderEvidence> evidences;

  const FolderSection({
    required this.id,
    required this.name,
    this.description,
    required this.evidences,
  });

  int get evidenceCount => evidences.length;
  bool get hasEvidence => evidences.isNotEmpty;

  @override
  List<Object?> get props => [id, name, description, evidences];
}

/// Carpeta anual de un enrollment
class AnnualFolder extends Equatable {
  final int id;
  final int enrollmentId;
  final int year;
  final String status;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final List<FolderSection> sections;

  const AnnualFolder({
    required this.id,
    required this.enrollmentId,
    required this.year,
    required this.status,
    this.submittedAt,
    this.createdAt,
    required this.sections,
  });

  AnnualFolderStatus get folderStatus {
    switch (status) {
      case 'submitted':
        return AnnualFolderStatus.submitted;
      case 'closed':
        return AnnualFolderStatus.closed;
      default:
        return AnnualFolderStatus.open;
    }
  }

  int get totalEvidences =>
      sections.fold(0, (sum, s) => sum + s.evidenceCount);

  int get sectionsWithEvidence =>
      sections.where((s) => s.hasEvidence).length;

  double get progress => sections.isEmpty
      ? 0
      : sectionsWithEvidence / sections.length;

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
