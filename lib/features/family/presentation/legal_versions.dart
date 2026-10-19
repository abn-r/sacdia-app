import '../../legal/domain/entities/legal_document.dart';

/// Versiones y URLs de los documentos legales vigentes, listas para enviar.
typedef LegalSnapshot = ({
  String termsVersion,
  String privacyVersion,
  String termsUrl,
  String privacyUrl,
});

/// Extrae Términos y Privacidad de [documents]; `null` si falta alguno (no se
/// puede registrar la aceptación en nombre del menor sin las dos versiones).
LegalSnapshot? legalSnapshotOf(List<LegalDocument>? documents) {
  if (documents == null) return null;
  LegalDocument? terms;
  LegalDocument? privacy;
  for (final doc in documents) {
    if (doc.documentType == LegalDocumentTypes.terms) terms = doc;
    if (doc.documentType == LegalDocumentTypes.privacy) privacy = doc;
  }
  if (terms == null || privacy == null) return null;
  return (
    termsVersion: terms.version,
    privacyVersion: privacy.version,
    termsUrl: terms.url,
    privacyUrl: privacy.url,
  );
}
