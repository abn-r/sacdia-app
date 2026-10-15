import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/certificate_import_file.dart';

class CertificateImportFileModel extends Equatable {
  final String id;
  final String url;
  final String name;
  final String type;
  final DateTime? uploadedAt;
  final int? pageCount;

  const CertificateImportFileModel({
    required this.id,
    required this.url,
    required this.name,
    required this.type,
    this.uploadedAt,
    this.pageCount,
  });

  factory CertificateImportFileModel.fromJson(Map<String, dynamic> json) {
    return CertificateImportFileModel(
      id: safeString(json['file_id'] ?? json['id']),
      url: safeString(json['file_url'] ?? json['url']),
      name: safeString(json['file_name'] ?? json['name']),
      type: safeString(json['file_type'] ?? json['type']),
      uploadedAt: DateTime.tryParse(safeString(json['uploaded_at'])),
      pageCount: _positive(json['page_count']),
    );
  }

  Map<String, dynamic> toJson() => {
        'file_id': id,
        'file_url': url,
        'file_name': name,
        'file_type': type,
        'uploaded_at': uploadedAt?.toIso8601String(),
        'page_count': pageCount,
      };

  CertificateImportFile toEntity() => CertificateImportFile(
        id: id,
        url: url,
        name: name,
        type: type,
        uploadedAt: uploadedAt,
        pageCount: pageCount,
      );

  /// R6: a missing, null or non-positive value means "no data".
  static int? _positive(dynamic value) {
    final parsed = safeIntOrNull(value);
    return parsed != null && parsed >= 1 ? parsed : null;
  }

  @override
  List<Object?> get props => [id, url, name, type, uploadedAt, pageCount];
}
