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

  /// URL firmada de Cloudflare R2 para mostrar / descargar el archivo.
  final String url;

  final String fileName;
  final EvidenceFileType type;

  final String uploadedByName;
  final DateTime uploadedAt;

  /// Nota del revisor (assistant-lf / director-lf) sobre este archivo.
  ///
  /// Escrita exclusivamente desde el panel admin (sacdia-admin).
  /// La app solo muestra este campo en modo lectura — nunca lo escribe.
  final String? reviewerNote;

  const EvidenceFile({
    required this.id,
    required this.url,
    required this.fileName,
    required this.type,
    required this.uploadedByName,
    required this.uploadedAt,
    this.reviewerNote,
  });

  bool get isImage => type == EvidenceFileType.image;
  bool get isPdf => type == EvidenceFileType.pdf;

  @override
  List<Object?> get props =>
      [id, url, fileName, type, uploadedByName, uploadedAt, reviewerNote];
}
