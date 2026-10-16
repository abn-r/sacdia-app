import '../../domain/entities/legal_status.dart';
import 'legal_document_model.dart';

/// Bloque `LegalStatus` del backend (GET/POST me y `/auth/me` `data.legal`).
class LegalStatusModel {
  final bool requiresAcceptance;
  final List<LegalDocumentStatusModel> documents;

  const LegalStatusModel({
    required this.requiresAcceptance,
    required this.documents,
  });

  factory LegalStatusModel.fromJson(Map<String, dynamic> json) {
    final docs = json['documents'] as List<dynamic>;
    return LegalStatusModel(
      requiresAcceptance: json['requires_acceptance'] as bool,
      documents: docs
          .map((d) =>
              LegalDocumentStatusModel.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  LegalStatus toEntity() => LegalStatus(
        requiresAcceptance: requiresAcceptance,
        documents: documents.map((d) => d.toEntity()).toList(),
      );
}
