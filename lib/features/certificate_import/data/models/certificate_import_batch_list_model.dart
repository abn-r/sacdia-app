import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/certificate_import_batch_list.dart';

/// Paginated list of the member's own certificate import batches.
class CertificateImportBatchListModel extends Equatable {
  final List<CertificateImportBatchSummaryModel> items;
  final int total;
  final int page;
  final int limit;

  const CertificateImportBatchListModel({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory CertificateImportBatchListModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return CertificateImportBatchListModel(
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(CertificateImportBatchSummaryModel.fromJson)
              .toList()
          : const [],
      total: safeIntOrNull(json['total']) ?? 0,
      page: safeIntOrNull(json['page']) ?? 1,
      limit: safeIntOrNull(json['limit']) ?? 20,
    );
  }

  CertificateImportBatchList toEntity() => CertificateImportBatchList(
        items: items
            .map(
              (item) => CertificateImportBatchSummary(
                id: item.id,
                status: item.status,
                createdAt: item.createdAt,
                modifiedAt: item.modifiedAt,
                fileCount: item.fileCount,
                itemCount: item.itemCount,
              ),
            )
            .toList(),
        total: total,
        page: page,
        limit: limit,
      );

  @override
  List<Object?> get props => [items, total, page, limit];
}

class CertificateImportBatchSummaryModel extends Equatable {
  final String id;
  final String status;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final int fileCount;
  final int itemCount;

  const CertificateImportBatchSummaryModel({
    required this.id,
    required this.status,
    this.createdAt,
    this.modifiedAt,
    this.fileCount = 0,
    this.itemCount = 0,
  });

  factory CertificateImportBatchSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawFiles = json['files'];
    final rawItems = json['items'];
    return CertificateImportBatchSummaryModel(
      id: safeString(json['batch_id'] ?? json['id']),
      status: safeString(json['status'], 'DRAFT'),
      createdAt: DateTime.tryParse(safeString(json['created_at'])),
      modifiedAt: DateTime.tryParse(safeString(json['modified_at'])),
      fileCount: rawFiles is List ? rawFiles.length : 0,
      itemCount: rawItems is List ? rawItems.length : 0,
    );
  }

  @override
  List<Object?> get props =>
      [id, status, createdAt, modifiedAt, fileCount, itemCount];
}
