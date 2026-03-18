import 'package:equatable/equatable.dart';

/// Tipo de archivo de evidencia.
enum EvidenceFileType { image, pdf }

/// Parsea la extensión / mime del archivo al enum correspondiente.
EvidenceFileType evidenceFileTypeFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'pdf':
      return EvidenceFileType.pdf;
    default:
      return EvidenceFileType.image;
  }
}

/// Un archivo de evidencia asociado a una [EvidenceSection].
class EvidenceFile extends Equatable {
  final String id;

  /// URL pública de Supabase Storage para mostrar / descargar el archivo.
  final String url;

  final String fileName;
  final EvidenceFileType type;

  final String uploadedByName;
  final DateTime uploadedAt;

  const EvidenceFile({
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
