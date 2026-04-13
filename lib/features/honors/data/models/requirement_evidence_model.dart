import 'package:equatable/equatable.dart';
import '../../domain/entities/requirement_evidence.dart';

/// Convierte un string del backend ('IMAGE', 'FILE', 'LINK') al enum [EvidenceType].
///
/// Fallback seguro a [EvidenceType.file] si el valor es desconocido.
EvidenceType _evidenceTypeFromString(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'IMAGE':
      return EvidenceType.image;
    case 'LINK':
      return EvidenceType.link;
    case 'FILE':
    default:
      return EvidenceType.file;
  }
}

/// Convierte un [EvidenceType] al string que espera el backend.
String _evidenceTypeToString(EvidenceType type) {
  switch (type) {
    case EvidenceType.image:
      return 'IMAGE';
    case EvidenceType.link:
      return 'LINK';
    case EvidenceType.file:
      return 'FILE';
  }
}

/// Modelo de evidencia de requisito para la capa de datos.
class RequirementEvidenceModel extends Equatable {
  final int id;
  final EvidenceType evidenceType;
  final String url;
  final String? filename;
  final String? mimeType;
  final int? fileSize;

  const RequirementEvidenceModel({
    required this.id,
    required this.evidenceType,
    required this.url,
    this.filename,
    this.mimeType,
    this.fileSize,
  });

  /// Crea una instancia desde JSON.
  ///
  /// El backend envía el tipo como string: 'IMAGE', 'FILE' o 'LINK'.
  factory RequirementEvidenceModel.fromJson(Map<String, dynamic> json) {
    return RequirementEvidenceModel(
      id: json['evidence_id'] as int,
      evidenceType: _evidenceTypeFromString(json['evidence_type'] as String?),
      url: json['url'] as String,
      filename: json['filename'] as String?,
      mimeType: json['mime_type'] as String?,
      fileSize: json['file_size'] as int?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'evidence_id': id,
      'evidence_type': _evidenceTypeToString(evidenceType),
      'url': url,
      'filename': filename,
      'mime_type': mimeType,
      'file_size': fileSize,
    };
  }

  /// Convierte el modelo a entidad de dominio
  RequirementEvidence toEntity() {
    return RequirementEvidence(
      id: id,
      evidenceType: evidenceType,
      url: url,
      filename: filename,
      mimeType: mimeType,
      fileSize: fileSize,
    );
  }

  RequirementEvidenceModel copyWith({
    int? id,
    EvidenceType? evidenceType,
    String? url,
    String? filename,
    String? mimeType,
    int? fileSize,
  }) {
    return RequirementEvidenceModel(
      id: id ?? this.id,
      evidenceType: evidenceType ?? this.evidenceType,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  @override
  List<Object?> get props => [
        id,
        evidenceType,
        url,
        filename,
        mimeType,
        fileSize,
      ];
}
