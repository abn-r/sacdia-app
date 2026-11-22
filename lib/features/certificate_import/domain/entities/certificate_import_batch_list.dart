import 'package:equatable/equatable.dart';

class CertificateImportBatchSummary extends Equatable {
  final String id;
  final String status;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final int fileCount;
  final int itemCount;

  /// Rows the reviewer sent back (status REJECTED). 0 when the list payload
  /// carries no row statuses.
  final int rejectedCount;

  const CertificateImportBatchSummary({
    required this.id,
    required this.status,
    this.createdAt,
    this.modifiedAt,
    this.fileCount = 0,
    this.itemCount = 0,
    this.rejectedCount = 0,
  });

  @override
  List<Object?> get props =>
      [id, status, createdAt, modifiedAt, fileCount, itemCount, rejectedCount];
}

class CertificateImportBatchList extends Equatable {
  final List<CertificateImportBatchSummary> items;
  final int total;
  final int page;
  final int limit;

  const CertificateImportBatchList({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  @override
  List<Object?> get props => [items, total, page, limit];
}
