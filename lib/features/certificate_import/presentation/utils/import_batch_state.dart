import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_batch_list.dart';
import '../../domain/entities/certificate_import_item.dart';

/// Where a batch status leads and how it reads on the entry screen.
enum ImportBatchStage { draft, inReview, corrections, partial, approved }

/// Maps the API batch status to a [ImportBatchStage]. Unknown values read as
/// "in review": the status screen can always open them.
ImportBatchStage importBatchStageOf(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
    case 'READY_TO_SUBMIT':
      return ImportBatchStage.draft;
    case 'REJECTED':
    case 'NEEDS_CORRECTION':
      return ImportBatchStage.corrections;
    case 'PARTIALLY_APPROVED':
      return ImportBatchStage.partial;
    case 'APPROVED':
      return ImportBatchStage.approved;
    default:
      return ImportBatchStage.inReview;
  }
}

/// Stage of a batch in the list. A reviewer can send a row back while the rest
/// are still pending, and the batch status stays "submitted" until every row
/// is decided: rejected rows in the summary mean the member has work to do, so
/// it reads as corrections, like the status screen does.
ImportBatchStage importSummaryStageOf(CertificateImportBatchSummary batch) {
  final stage = importBatchStageOf(batch.status);
  final sent =
      stage == ImportBatchStage.inReview || stage == ImportBatchStage.partial;
  return sent && batch.rejectedCount > 0 ? ImportBatchStage.corrections : stage;
}

/// Where a sent batch stands as a whole.
enum ImportBatchStateKind { inReview, corrections, partial, approved }

/// A row the reviewer sent back and the member has to fix.
bool importItemNeedsFix(CertificateImportItem item) =>
    item.isRejected ||
    (item.rejectionReason != null &&
        item.status != CertificateImportItemStatus.approved &&
        item.status != CertificateImportItemStatus.resubmitted);

/// The rows of a batch by what the member can do with them.
class ImportItemGroups {
  const ImportItemGroups({
    required this.toFix,
    required this.inReview,
    required this.approved,
  });

  /// Sent back by the reviewer: reason shown, tap to correct and resubmit.
  final List<CertificateImportItem> toFix;

  /// Everything else the member kept: sent (or resent) and waiting.
  final List<CertificateImportItem> inReview;
  final List<CertificateImportItem> approved;

  factory ImportItemGroups.of(Iterable<CertificateImportItem> items) {
    final toFix = <CertificateImportItem>[];
    final inReview = <CertificateImportItem>[];
    final approved = <CertificateImportItem>[];
    for (final item in items) {
      if (importItemNeedsFix(item)) {
        toFix.add(item);
      } else if (item.status == CertificateImportItemStatus.approved) {
        approved.add(item);
      } else {
        inReview.add(item);
      }
    }
    return ImportItemGroups(
      toFix: toFix,
      inReview: inReview,
      approved: approved,
    );
  }

  int get total => toFix.length + inReview.length + approved.length;
}

/// The state of a batch, derived from the status of its rows (and, when the
/// rows say nothing, from the batch status).
class ImportBatchState {
  const ImportBatchState({
    required this.kind,
    required this.groups,
  });

  final ImportBatchStateKind kind;
  final ImportItemGroups groups;

  int get toFixCount => groups.toFix.length;
  int get approvedCount => groups.approved.length;
  int get total => groups.total;

  factory ImportBatchState.of(CertificateImportBatch batch) {
    final groups = ImportItemGroups.of(batch.activeItems);
    final stage = importBatchStageOf(batch.status);
    final ImportBatchStateKind kind;
    if (groups.toFix.isNotEmpty) {
      kind = ImportBatchStateKind.corrections;
    } else if (groups.total > 0
        ? groups.approved.length == groups.total
        : stage == ImportBatchStage.approved) {
      kind = ImportBatchStateKind.approved;
    } else if (groups.approved.isNotEmpty ||
        stage == ImportBatchStage.partial) {
      kind = ImportBatchStateKind.partial;
    } else {
      kind = ImportBatchStateKind.inReview;
    }
    return ImportBatchState(kind: kind, groups: groups);
  }
}
