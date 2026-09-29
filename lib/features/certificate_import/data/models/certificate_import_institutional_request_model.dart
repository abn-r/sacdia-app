import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/certificate_import_institutional_request.dart';

/// Institutional request for Guía Mayor Avanzado (GM-02) / Instructor (GM-03).
/// Approving this request is NOT "clase registrada" and does not create enrollment.
class CertificateImportInstitutionalRequestModel extends Equatable {
  final String id;
  final String status;
  final String? classAssetCode;
  final String? className;
  final String? decisionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const CertificateImportInstitutionalRequestModel({
    required this.id,
    required this.status,
    this.classAssetCode,
    this.className,
    this.decisionReason,
    this.createdAt,
    this.reviewedAt,
  });

  factory CertificateImportInstitutionalRequestModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CertificateImportInstitutionalRequestModel(
      id: safeString(json['request_id'] ?? json['id']),
      status: safeString(json['status'], 'PENDING'),
      classAssetCode: safeStringOrNull(
        json['class_asset_code'] ?? json['asset_code'],
      ),
      className: safeStringOrNull(json['class_name'] ?? json['detected_name']),
      decisionReason: safeStringOrNull(
        json['decision_reason'] ?? json['rejection_reason'],
      ),
      createdAt: DateTime.tryParse(safeString(json['created_at'])),
      reviewedAt: DateTime.tryParse(
        safeString(json['reviewed_at'] ?? json['decided_at']),
      ),
    );
  }

  CertificateImportInstitutionalRequest toEntity() =>
      CertificateImportInstitutionalRequest(
        id: id,
        status: status,
        classAssetCode: classAssetCode,
        className: className,
        decisionReason: decisionReason,
        createdAt: createdAt,
        reviewedAt: reviewedAt,
      );

  @override
  List<Object?> get props => [
        id,
        status,
        classAssetCode,
        className,
        decisionReason,
        createdAt,
        reviewedAt,
      ];
}

class CertificateImportInstitutionalRequestListModel extends Equatable {
  final List<CertificateImportInstitutionalRequestModel> items;
  final int total;
  final int page;
  final int limit;

  const CertificateImportInstitutionalRequestListModel({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory CertificateImportInstitutionalRequestListModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'] ?? json['data'];
    return CertificateImportInstitutionalRequestListModel(
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(CertificateImportInstitutionalRequestModel.fromJson)
              .toList()
          : const [],
      total: safeIntOrNull(json['total']) ?? 0,
      page: safeIntOrNull(json['page']) ?? 1,
      limit: safeIntOrNull(json['limit']) ?? 20,
    );
  }

  CertificateImportInstitutionalRequestList toEntity() =>
      CertificateImportInstitutionalRequestList(
        items: items.map((item) => item.toEntity()).toList(),
        total: total,
        page: page,
        limit: limit,
      );

  @override
  List<Object?> get props => [items, total, page, limit];
}
