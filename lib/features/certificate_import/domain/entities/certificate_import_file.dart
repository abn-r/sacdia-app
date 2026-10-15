import 'package:equatable/equatable.dart';

class CertificateImportFile extends Equatable {
  final String id;
  final String url;
  final String name;
  final String type;
  final DateTime? uploadedAt;

  /// Null when the API does not report it (files uploaded before D4).
  final int? pageCount;

  const CertificateImportFile({
    required this.id,
    required this.url,
    required this.name,
    required this.type,
    this.uploadedAt,
    this.pageCount,
  });

  @override
  List<Object?> get props => [id, url, name, type, uploadedAt, pageCount];
}
