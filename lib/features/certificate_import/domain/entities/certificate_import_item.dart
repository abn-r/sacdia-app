import 'package:equatable/equatable.dart';

enum CertificateImportItemType { honor, clazz, unknown }

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
  });

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
      ];
}
