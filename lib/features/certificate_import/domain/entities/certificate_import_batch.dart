import 'package:equatable/equatable.dart';
import 'certificate_import_file.dart';
import 'certificate_import_item.dart';
import 'certificate_import_ocr_state.dart';

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

  /// Reading state reported by the API. `null` with [hasOcrState] means OCR
  /// was never requested for this batch.
  final CertificateImportOcrState? ocrState;

  /// False when the API did not send `ocr_state` at all (backend without
  /// the field): callers fall back to checking whether rows arrived.
  final bool hasOcrState;

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
    this.ocrState,
    this.hasOcrState = false,
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
        ocrState,
        hasOcrState,
      ];
}
