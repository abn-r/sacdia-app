import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/certificate_import_file.dart';

class CertificateImportFileModel extends Equatable {
  final String id;
  final String url;
  final String name;
  final String type;
  final DateTime? uploadedAt;

  const CertificateImportFileModel({
    required this.id,
    required this.url,
    required this.name,
    required this.type,
    this.uploadedAt,
  });

  factory CertificateImportFileModel.fromJson(Map<String, dynamic> json) {
    return CertificateImportFileModel(
      id: safeString(json['file_id'] ?? json['id']),
      url: safeString(json['file_url'] ?? json['url']),
      name: safeString(json['file_name'] ?? json['name']),
      type: safeString(json['file_type'] ?? json['type']),
      uploadedAt: DateTime.tryParse(safeString(json['uploaded_at'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'file_id': id,
        'file_url': url,
        'file_name': name,
        'file_type': type,
        'uploaded_at': uploadedAt?.toIso8601String(),
      };

  CertificateImportFile toEntity() => CertificateImportFile(
        id: id,
        url: url,
        name: name,
        type: type,
        uploadedAt: uploadedAt,
      );

  @override
  List<Object?> get props => [id, url, name, type, uploadedAt];
}
