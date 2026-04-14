import 'package:sacdia_app/core/utils/app_logger.dart';
import '../../domain/entities/evidence_file.dart';

const String _tag = 'EvidenceFileModel';

/// Modelo de datos para [EvidenceFile].
///
/// Mapea la respuesta JSON del módulo AnnualFolders al dominio y viceversa.
/// Campos AnnualFolders: evidence_id, file_url, file_name, uploaded_by, created_at.
class EvidenceFileModel extends EvidenceFile {
  const EvidenceFileModel({
    required super.id,
    required super.url,
    required super.fileName,
    required super.type,
    required super.uploadedByName,
    required super.uploadedAt,
    super.reviewerNote,
  });

  factory EvidenceFileModel.fromJson(Map<String, dynamic> json) {
    final fileName =
        (json['file_name'] ?? json['fileName'] ?? '').toString();

    // reviewer_note: string o null — escrito por el revisor desde el admin
    final rawNote = json['reviewer_note'] ?? json['reviewerNote'];
    final reviewerNote =
        (rawNote != null && rawNote.toString().isNotEmpty)
            ? rawNote.toString()
            : null;

    return EvidenceFileModel(
      // AnnualFolders usa evidence_id; fallback al campo genérico id/file_id
      id: (json['evidence_id'] ?? json['id'] ?? json['file_id'] ?? '')
          .toString(),
      // AnnualFolders usa file_url; fallback a url
      url: (json['file_url'] ?? json['url'] ?? '').toString(),
      fileName: fileName,
      // AnnualFolders no envía file_type — se deriva de la extensión del nombre
      type: _typeFromFileName(
        fileName,
        fallback: json['file_type'] ?? json['type'],
      ),
      // AnnualFolders usa uploaded_by (string con el nombre directamente)
      uploadedByName: (json['uploaded_by'] ??
              json['uploaded_by_name'] ??
              json['uploadedByName'] ??
              'Desconocido')
          .toString(),
      // AnnualFolders usa created_at; fallback a uploaded_at
      uploadedAt: () {
        final raw = json['created_at'] ?? json['uploaded_at'] ?? json['uploadedAt'];
        if (raw != null) {
          final parsed = DateTime.tryParse(raw.toString());
          if (parsed == null) {
            AppLogger.w(
                'Failed to parse date: $raw, using DateTime.now()',
                tag: _tag);
          }
          return parsed ?? DateTime.now();
        }
        return DateTime.now();
      }(),
      reviewerNote: reviewerNote,
    );
  }

  /// Deriva [EvidenceFileType] de la extensión del nombre de archivo.
  /// Acepta un [fallback] string por si el JSON incluye un campo explícito.
  static EvidenceFileType _typeFromFileName(
    String fileName, {
    dynamic fallback,
  }) {
    if (fallback != null) {
      return evidenceFileTypeFromString(fallback.toString());
    }
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    return ext == 'pdf' ? EvidenceFileType.pdf : EvidenceFileType.image;
  }

  Map<String, dynamic> toJson() {
    return {
      'evidence_id': id,
      'file_url': url,
      'file_name': fileName,
      'file_type': type == EvidenceFileType.pdf ? 'pdf' : 'image',
      'uploaded_by': uploadedByName,
      'created_at': uploadedAt.toIso8601String(),
      // reviewer_note es read-only en el app; se incluye en toJson solo para
      // serialización completa (e.g. cache local). El app nunca lo escribe al backend.
      if (reviewerNote != null) 'reviewer_note': reviewerNote,
    };
  }

  /// Crea un [EvidenceFileModel] desde una entidad del dominio.
  factory EvidenceFileModel.fromEntity(EvidenceFile entity) {
    return EvidenceFileModel(
      id: entity.id,
      url: entity.url,
      fileName: entity.fileName,
      type: entity.type,
      uploadedByName: entity.uploadedByName,
      uploadedAt: entity.uploadedAt,
      reviewerNote: entity.reviewerNote,
    );
  }

  EvidenceFile toEntity() => EvidenceFile(
        id: id,
        url: url,
        fileName: fileName,
        type: type,
        uploadedByName: uploadedByName,
        uploadedAt: uploadedAt,
        reviewerNote: reviewerNote,
      );
}
