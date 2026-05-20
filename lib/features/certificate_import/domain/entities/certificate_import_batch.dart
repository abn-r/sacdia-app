import 'package:equatable/equatable.dart';
import 'certificate_import_file.dart';
import 'certificate_import_item.dart';

class CertificateImportBatch extends Equatable {
  final String id;
  final String status;
  final int? localFieldId;
  final List<CertificateImportFile> files;
  final List<CertificateImportItem> items;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  const CertificateImportBatch({
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

  int get readyCount => items.where((item) => item.isReady).length;
  int get needsReviewCount => items.where((item) => item.needsReview).length;
  int get rejectedCount => items.where((item) => item.isRejected).length;

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
