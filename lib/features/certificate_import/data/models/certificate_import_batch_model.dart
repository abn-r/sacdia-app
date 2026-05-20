export '../../domain/entities/certificate_import_item.dart';

import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/certificate_import_batch.dart';
import 'certificate_import_file_model.dart';
import 'certificate_import_item_model.dart';

class CertificateImportBatchModel extends Equatable {
  final String id;
  final String status;
  final int? localFieldId;
  final List<CertificateImportFileModel> files;
  final List<CertificateImportItemModel> items;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  const CertificateImportBatchModel({
    required this.id,
    required this.status,
    this.localFieldId,
    this.files = const [],
    this.items = const [],
    this.submittedAt,
    this.reviewedAt,
    this.createdAt,
    this.modifiedAt,
  });

  factory CertificateImportBatchModel.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final rawItems = json['items'];
    return CertificateImportBatchModel(
      id: safeString(json['batch_id'] ?? json['id']),
      status: safeString(json['status'], 'DRAFT'),
      localFieldId: safeIntOrNull(json['local_field_id']),
      files: rawFiles is List
          ? rawFiles
              .whereType<Map<String, dynamic>>()
              .map(CertificateImportFileModel.fromJson)
              .toList()
          : const [],
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(CertificateImportItemModel.fromJson)
              .toList()
          : const [],
      submittedAt: _parseDate(json['submitted_at']),
      reviewedAt: _parseDate(json['reviewed_at']),
      createdAt: _parseDate(json['created_at']),
      modifiedAt: _parseDate(json['modified_at']),
    );
  }

  int get readyCount => items.where((item) => item.toEntity().isReady).length;
  int get needsReviewCount =>
      items.where((item) => item.toEntity().needsReview).length;
  int get rejectedCount =>
      items.where((item) => item.toEntity().isRejected).length;

  Map<String, dynamic> toJson() => {
        'batch_id': id,
        'status': status,
        'local_field_id': localFieldId,
        'files': files.map((file) => file.toJson()).toList(),
        'items': items.map((item) => item.toJson()).toList(),
        'submitted_at': submittedAt?.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'modified_at': modifiedAt?.toIso8601String(),
      };

  CertificateImportBatch toEntity() => CertificateImportBatch(
        id: id,
        status: status,
        localFieldId: localFieldId,
        files: files.map((file) => file.toEntity()).toList(),
        items: items.map((item) => item.toEntity()).toList(),
        submittedAt: submittedAt,
        reviewedAt: reviewedAt,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      );

  static DateTime? _parseDate(dynamic value) {
    final raw = safeStringOrNull(value);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  List<Object?> get props => [
        id,
        status,
        localFieldId,
        files,
        items,
        submittedAt,
        reviewedAt,
        createdAt,
        modifiedAt,
      ];
}
