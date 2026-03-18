import '../../domain/entities/evidence_file.dart';

/// Modelo de datos para [EvidenceFile].
///
/// Mapea la respuesta JSON de la API al dominio y viceversa.
class EvidenceFileModel extends EvidenceFile {
  const EvidenceFileModel({
    required super.id,
    required super.url,
    required super.fileName,
    required super.type,
    required super.uploadedByName,
    required super.uploadedAt,
  });

  factory EvidenceFileModel.fromJson(Map<String, dynamic> json) {
    return EvidenceFileModel(
      id: (json['id'] ?? json['file_id'] ?? '').toString(),
      url: (json['url'] ?? json['file_url'] ?? '').toString(),
      fileName: (json['file_name'] ?? json['fileName'] ?? '').toString(),
      type: evidenceFileTypeFromString(
        json['file_type'] ?? json['type'] ?? '',
      ),
      uploadedByName: (json['uploaded_by_name'] ??
              json['uploadedByName'] ??
              'Desconocido')
          .toString(),
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at'].toString()) ?? DateTime.now()
          : json['uploadedAt'] != null
              ? DateTime.tryParse(json['uploadedAt'].toString()) ?? DateTime.now()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'file_name': fileName,
      'file_type': type == EvidenceFileType.pdf ? 'pdf' : 'image',
      'uploaded_by_name': uploadedByName,
      'uploaded_at': uploadedAt.toIso8601String(),
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
    );
  }

  EvidenceFile toEntity() => EvidenceFile(
        id: id,
        url: url,
        fileName: fileName,
        type: type,
        uploadedByName: uploadedByName,
        uploadedAt: uploadedAt,
      );
}
