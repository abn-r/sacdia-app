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

  @override
  List<Object?> get props => [
        id,
        batchId,
        type,
        honorId,
        classId,
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
