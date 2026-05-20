import 'package:equatable/equatable.dart';

class CertificateImportFile extends Equatable {
  final String id;
  final String url;
  final String name;
  final String type;
  final DateTime? uploadedAt;

  const CertificateImportFile({
    required this.id,
    required this.url,
    required this.name,
    required this.type,
    this.uploadedAt,
  });

  @override
  List<Object?> get props => [id, url, name, type, uploadedAt];
}
