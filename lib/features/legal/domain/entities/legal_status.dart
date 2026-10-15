import 'package:equatable/equatable.dart';
import 'legal_document.dart';

/// Estado de aceptación legal del usuario actual.
class LegalStatus extends Equatable {
  final bool requiresAcceptance;
  final List<LegalDocumentStatus> documents;

  const LegalStatus({
    required this.requiresAcceptance,
    required this.documents,
  });

  /// Documento del [documentType] dado, o null si el backend no lo envió.
  LegalDocumentStatus? documentOf(String documentType) {
    for (final doc in documents) {
      if (doc.documentType == documentType) return doc;
    }
    return null;
  }

  /// Versión vigente del [documentType] dado, o null si no vino en la respuesta.
  String? versionOf(String documentType) => documentOf(documentType)?.version;

  @override
  List<Object?> get props => [requiresAcceptance, documents];
}
