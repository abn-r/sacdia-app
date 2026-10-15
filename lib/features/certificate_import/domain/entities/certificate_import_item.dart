import 'package:equatable/equatable.dart';

import 'certificate_import_item_refs.dart';

export 'certificate_import_item_refs.dart';

enum CertificateImportItemType { honor, clazz, unknown }

/// A date confidence below this asks the member to double-check the date (D5).
const double kDateReviewThreshold = 0.8;

/// What a row still needs before it can be sent.
enum CertificateImportMissing { type, honor, clazz, date, name }

enum CertificateImportItemStatus {
  needsReview,
  ready,
  submitted,
  approved,
  rejected,
  resubmitted,
  unknown,
}

class CertificateImportItem extends Equatable {
  final String id;
  final String? batchId;
  final CertificateImportItemType type;
  final int? honorId;
  final int? classId;
  final String? classAssetCode;
  final String? detectedName;
  final DateTime? detectedDate;
  final DateTime? completedAt;
  final double? ocrConfidence;
  final Map<String, dynamic>? fieldConfidence;
  final CertificateImportItemStatus status;
  final String? rejectionReason;
  final String? appliedEntityType;
  final int? appliedEntityId;

  /// Page of [sourceFileId] where OCR read the row (D4, 1-based). Null when
  /// the row is manual or the backend does not send it yet (R6).
  final int? sourcePage;

  /// File of the batch the row was read from (D12). Null when unknown.
  final String? sourceFileId;

  /// Catalog selection with display names (R6: null when the API omits them).
  final CertificateImportHonorRef? honor;
  final CertificateImportClassRef? classRef;
  final CertificateImportInstructorRef? instructor;

  /// False for a row the member removed from the list. The API keeps it, so
  /// it can still come back inside `items`; no view may count or list it.
  /// A payload without the field means active (R6).
  final bool active;

  /// Times the row was saved. 0 is a row nobody has edited since the reading;
  /// above 0 the member saved it, so the date was seen and confirmed.
  final int revision;

  const CertificateImportItem({
    required this.id,
    this.batchId,
    required this.type,
    this.honorId,
    this.classId,
    this.classAssetCode,
    this.detectedName,
    this.detectedDate,
    this.completedAt,
    this.ocrConfidence,
    this.fieldConfidence,
    required this.status,
    this.rejectionReason,
    this.appliedEntityType,
    this.appliedEntityId,
    this.sourcePage,
    this.sourceFileId,
    this.honor,
    this.classRef,
    this.instructor,
    this.active = true,
    this.revision = 0,
  });

  /// Everything the row still needs, in the order the member should see it.
  List<CertificateImportMissing> get missing {
    if (type == CertificateImportItemType.unknown) {
      return const [CertificateImportMissing.type];
    }
    final isHonor = type == CertificateImportItemType.honor;
    return [
      if (isHonor && honorId == null) CertificateImportMissing.honor,
      if (!isHonor && classId == null) CertificateImportMissing.clazz,
      if (completedAt == null) CertificateImportMissing.date,
      if (!(detectedName?.trim().isNotEmpty ?? false))
        CertificateImportMissing.name,
    ];
  }

  bool get isComplete => missing.isEmpty;

  /// Catalog name when chosen, otherwise what the OCR read.
  String? get displayName =>
      (type == CertificateImportItemType.honor
          ? honor?.name
          : classRef?.name) ??
      (detectedName?.trim().isEmpty ?? true ? null : detectedName!.trim());

  /// True when the OCR date confidence is known and under
  /// [kDateReviewThreshold] and the member has not saved the row yet.
  ///
  /// Saving needs a date, and the editor shows it with this same notice, so a
  /// row saved by the member (`revision` above 0) counts as confirmed. The
  /// confidence itself never changes: it describes what the OCR read.
  bool get needsDateReview {
    if (revision > 0) return false;
    final raw = fieldConfidence?['date'];
    return raw is num && raw < kDateReviewThreshold;
  }

  bool get isReady =>
      status == CertificateImportItemStatus.ready ||
      status == CertificateImportItemStatus.submitted ||
      status == CertificateImportItemStatus.resubmitted ||
      status == CertificateImportItemStatus.approved;

  bool get needsReview => status == CertificateImportItemStatus.needsReview;

  bool get isRejected => status == CertificateImportItemStatus.rejected;

  /// GM-01: approved certificate replaces the current enrollment — not two.
  bool get isGuiaMayorBase {
    final code = (classAssetCode ?? '').toUpperCase();
    if (code == 'GM-01') return true;
    final name = (detectedName ?? '').toLowerCase();
    return name.contains('guía mayor') &&
        !name.contains('avanzado') &&
        !name.contains('instructor');
  }

  /// GM-02 / GM-03 go to institutional review; approval ≠ enrollment.
  bool get isInstitutionalClass {
    final code = (classAssetCode ?? '').toUpperCase();
    if (code == 'GM-02' || code == 'GM-03') return true;
    final name = (detectedName ?? '').toLowerCase();
    return name.contains('avanzado') || name.contains('instructor');
  }

  bool get isPendingAdministrativePeriod {
    final reason = (rejectionReason ?? '').toUpperCase();
    return reason.contains('PERIOD') ||
        reason.contains('PERIODO') ||
        reason.contains('ECCLESIASTICAL_YEAR');
  }

  @override
  List<Object?> get props => [
        id,
        batchId,
        type,
        honorId,
        classId,
        classAssetCode,
        detectedName,
        detectedDate,
        completedAt,
        ocrConfidence,
        fieldConfidence,
        status,
        rejectionReason,
        appliedEntityType,
        appliedEntityId,
        sourcePage,
        sourceFileId,
        honor,
        classRef,
        instructor,
        active,
        revision,
      ];
}
