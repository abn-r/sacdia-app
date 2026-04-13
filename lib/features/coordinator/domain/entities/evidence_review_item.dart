import 'package:equatable/equatable.dart';

/// Tipo de evidencia que puede ser revisada.
enum EvidenceReviewType {
  folder,
  classType,
  honor;

  static EvidenceReviewType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'folder':
        return EvidenceReviewType.folder;
      case 'class':
        return EvidenceReviewType.classType;
      case 'honor':
        return EvidenceReviewType.honor;
      default:
        return EvidenceReviewType.folder;
    }
  }

  String get apiValue {
    switch (this) {
      case EvidenceReviewType.folder:
        return 'folder';
      case EvidenceReviewType.classType:
        return 'class';
      case EvidenceReviewType.honor:
        return 'honor';
    }
  }

  String get displayLabel {
    switch (this) {
      case EvidenceReviewType.folder:
        return 'Carpeta';
      case EvidenceReviewType.classType:
        return 'Clase';
      case EvidenceReviewType.honor:
        return 'Honor';
    }
  }
}

/// Estado de revisión de una evidencia.
enum EvidenceReviewStatus {
  pending,
  approved,
  rejected;

  static EvidenceReviewStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return EvidenceReviewStatus.approved;
      case 'rejected':
        return EvidenceReviewStatus.rejected;
      default:
        return EvidenceReviewStatus.pending;
    }
  }
}

/// Archivo adjunto a una evidencia.
class EvidenceFile extends Equatable {
  final String id;
  final String url;
  final String? name;
  final String? mimeType;

  const EvidenceFile({
    required this.id,
    required this.url,
    this.name,
    this.mimeType,
  });

  bool get isImage {
    final mt = mimeType?.toLowerCase() ?? '';
    return mt.startsWith('image/') ||
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.webp');
  }

  bool get isPdf {
    return (mimeType?.toLowerCase().contains('pdf') ?? false) ||
        url.toLowerCase().endsWith('.pdf');
  }

  @override
  List<Object?> get props => [id, url, name, mimeType];
}

/// Entrada del historial de validación de una evidencia.
class EvidenceHistoryEntry extends Equatable {
  final String id;
  final String action;
  final String? actorName;
  final String? comment;
  final DateTime createdAt;

  const EvidenceHistoryEntry({
    required this.id,
    required this.action,
    this.actorName,
    this.comment,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, action, actorName, comment, createdAt];
}

/// Entidad de ítem de revisión de evidencia.
///
/// Devuelto por GET /evidence-review/pending y GET /evidence-review/:type/:id.
class EvidenceReviewItem extends Equatable {
  final String id;
  final EvidenceReviewType type;
  final EvidenceReviewStatus status;
  final String memberName;
  final String? memberPhotoUrl;
  final String? context;
  final DateTime submittedAt;
  final int fileCount;
  final List<EvidenceFile> files;
  final List<EvidenceHistoryEntry> history;

  const EvidenceReviewItem({
    required this.id,
    required this.type,
    required this.status,
    required this.memberName,
    this.memberPhotoUrl,
    this.context,
    required this.submittedAt,
    required this.fileCount,
    this.files = const [],
    this.history = const [],
  });

  @override
  List<Object?> get props => [
        id,
        type,
        status,
        memberName,
        memberPhotoUrl,
        context,
        submittedAt,
        fileCount,
        files,
        history,
      ];
}
