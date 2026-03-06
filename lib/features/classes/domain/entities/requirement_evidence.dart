import 'package:equatable/equatable.dart';

/// Tipo de archivo de evidencia de requerimiento.
enum EvidenceFileType { image, pdf }

/// Parsea la extension / mime del archivo al enum correspondiente.
EvidenceFileType evidenceFileTypeFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'pdf':
      return EvidenceFileType.pdf;
    default:
      return EvidenceFileType.image;
  }
}

/// Un archivo de evidencia asociado a un [ClassRequirement].
class RequirementEvidence extends Equatable {
  final String id;

  /// URL publica de Supabase Storage para mostrar / descargar el archivo.
  final String url;

  final String fileName;
  final EvidenceFileType type;

  final String uploadedByName;
  final DateTime uploadedAt;

  const RequirementEvidence({
    required this.id,
    required this.url,
    required this.fileName,
    required this.type,
    required this.uploadedByName,
    required this.uploadedAt,
  });

  bool get isImage => type == EvidenceFileType.image;
  bool get isPdf => type == EvidenceFileType.pdf;

  @override
  List<Object?> get props =>
      [id, url, fileName, type, uploadedByName, uploadedAt];
}
