import 'package:equatable/equatable.dart';

/// Tipos de documento legal manejados por el backend (`document_type`).
abstract final class LegalDocumentTypes {
  static const String terms = 'terms';
  static const String privacy = 'privacy';
}

/// Documento legal vigente: tipo, versión y URL pública.
class LegalDocument extends Equatable {
  final String documentType;
  final String version;
  final String url;

  const LegalDocument({
    required this.documentType,
    required this.version,
    required this.url,
  });

  @override
  List<Object?> get props => [documentType, version, url];
}

/// Documento legal vigente más el estado de aceptación del usuario actual.
class LegalDocumentStatus extends LegalDocument {
  final bool accepted;
  final DateTime? acceptedAt;

  const LegalDocumentStatus({
    required super.documentType,
    required super.version,
    required super.url,
    required this.accepted,
    this.acceptedAt,
  });

  @override
  List<Object?> get props => [...super.props, accepted, acceptedAt];
}
