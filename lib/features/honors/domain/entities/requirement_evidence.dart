import 'package:equatable/equatable.dart';

/// Tipos de evidencia soportados para un requisito de especialidad.
enum EvidenceType {
  /// Imagen adjunta (foto, captura de pantalla).
  image,

  /// Archivo adjunto (PDF, documento, etc.).
  file,

  /// Enlace externo (URL a un recurso web).
  link,
}

/// Entidad de evidencia de requisito del dominio.
///
/// Representa un archivo, imagen o enlace que el usuario adjunta
/// para demostrar el cumplimiento de un requisito de especialidad.
class RequirementEvidence extends Equatable {
  final int id;

  /// Tipo de evidencia: imagen, archivo o enlace.
  final EvidenceType evidenceType;

  /// URL pública o firmada del recurso.
  final String url;

  /// Nombre original del archivo, presente cuando [evidenceType] es [EvidenceType.file]
  /// o [EvidenceType.image].
  final String? filename;

  /// MIME type del archivo, ej. "image/jpeg", "application/pdf".
  final String? mimeType;

  /// Tamaño del archivo en bytes.
  final int? fileSize;

  const RequirementEvidence({
    required this.id,
    required this.evidenceType,
    required this.url,
    this.filename,
    this.mimeType,
    this.fileSize,
  });

  RequirementEvidence copyWith({
    int? id,
    EvidenceType? evidenceType,
    String? url,
    String? filename,
    String? mimeType,
    int? fileSize,
  }) {
    return RequirementEvidence(
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
