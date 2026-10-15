import '../../domain/entities/legal_document.dart';

/// Parsea las claves exactas del backend (`document_type`, `version`, `url`).
class LegalDocumentModel {
  final String documentType;
  final String version;
  final String url;

  const LegalDocumentModel({
    required this.documentType,
    required this.version,
    required this.url,
  });

  factory LegalDocumentModel.fromJson(Map<String, dynamic> json) {
    return LegalDocumentModel(
      documentType: json['document_type'] as String,
      version: json['version'] as String,
      url: json['url'] as String,
    );
  }

  LegalDocument toEntity() => LegalDocument(
        documentType: documentType,
        version: version,
        url: url,
      );
}

/// Documento con su estado de aceptación (`accepted`, `accepted_at`).
class LegalDocumentStatusModel extends LegalDocumentModel {
  final bool accepted;
  final DateTime? acceptedAt;

  const LegalDocumentStatusModel({
    required super.documentType,
    required super.version,
    required super.url,
    required this.accepted,
    this.acceptedAt,
  });

  factory LegalDocumentStatusModel.fromJson(Map<String, dynamic> json) {
    final acceptedAt = json['accepted_at'];
    return LegalDocumentStatusModel(
      documentType: json['document_type'] as String,
      version: json['version'] as String,
      url: json['url'] as String,
      accepted: json['accepted'] as bool,
      acceptedAt: acceptedAt is String ? DateTime.tryParse(acceptedAt) : null,
    );
  }

  @override
  LegalDocumentStatus toEntity() => LegalDocumentStatus(
        documentType: documentType,
        version: version,
        url: url,
        accepted: accepted,
        acceptedAt: acceptedAt,
      );
}
