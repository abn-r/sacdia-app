import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/certificate_import_item.dart';

class CertificateImportItemModel extends Equatable {
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

  const CertificateImportItemModel({
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

  factory CertificateImportItemModel.fromJson(Map<String, dynamic> json) {
    final rawFieldConfidence = json['field_confidence'];
    return CertificateImportItemModel(
      id: safeString(json['item_id'] ?? json['id']),
      batchId: safeStringOrNull(json['batch_id']),
      type: parseItemType(safeString(json['item_type'] ?? json['type'])),
      honorId: safeIntOrNull(json['honor_id']),
      classId: safeIntOrNull(json['class_id']),
      detectedName: safeStringOrNull(json['detected_name']),
      detectedDate: _parseDate(json['detected_date']),
      completedAt: _parseDate(json['completed_at']),
      ocrConfidence: safeDouble(json['ocr_confidence'], double.nan).isNaN
          ? null
          : safeDouble(json['ocr_confidence']),
      fieldConfidence: rawFieldConfidence is Map<String, dynamic>
          ? rawFieldConfidence
          : null,
      status: parseItemStatus(safeString(json['status'])),
      rejectionReason: safeStringOrNull(json['rejection_reason']),
      appliedEntityType: safeStringOrNull(json['applied_entity_type']),
      appliedEntityId: safeIntOrNull(json['applied_entity_id']),
    );
  }

  static CertificateImportItemType parseItemType(String value) {
    switch (value.toUpperCase()) {
      case 'HONOR':
        return CertificateImportItemType.honor;
      case 'CLASS':
        return CertificateImportItemType.clazz;
      default:
        return CertificateImportItemType.unknown;
    }
  }

  static CertificateImportItemStatus parseItemStatus(String value) {
    switch (value.toUpperCase()) {
      case 'NEEDS_REVIEW':
        return CertificateImportItemStatus.needsReview;
      case 'READY':
        return CertificateImportItemStatus.ready;
      case 'SUBMITTED':
        return CertificateImportItemStatus.submitted;
      case 'APPROVED':
        return CertificateImportItemStatus.approved;
      case 'REJECTED':
        return CertificateImportItemStatus.rejected;
      case 'RESUBMITTED':
        return CertificateImportItemStatus.resubmitted;
      default:
        return CertificateImportItemStatus.unknown;
    }
  }

  Map<String, dynamic> toJson() => {
        'item_id': id,
        'batch_id': batchId,
        'item_type': switch (type) {
          CertificateImportItemType.honor => 'HONOR',
          CertificateImportItemType.clazz => 'CLASS',
          CertificateImportItemType.unknown => 'UNKNOWN',
        },
        'honor_id': honorId,
        'class_id': classId,
        'detected_name': detectedName,
        'detected_date': _formatDate(detectedDate),
        'completed_at': _formatDate(completedAt),
        'ocr_confidence': ocrConfidence,
        'field_confidence': fieldConfidence,
        'status': switch (status) {
          CertificateImportItemStatus.needsReview => 'NEEDS_REVIEW',
          CertificateImportItemStatus.ready => 'READY',
          CertificateImportItemStatus.submitted => 'SUBMITTED',
          CertificateImportItemStatus.approved => 'APPROVED',
          CertificateImportItemStatus.rejected => 'REJECTED',
          CertificateImportItemStatus.resubmitted => 'RESUBMITTED',
          CertificateImportItemStatus.unknown => 'UNKNOWN',
        },
        'rejection_reason': rejectionReason,
        'applied_entity_type': appliedEntityType,
        'applied_entity_id': appliedEntityId,
      };

  CertificateImportItem toEntity() => CertificateImportItem(
        id: id,
        batchId: batchId,
        type: type,
        honorId: honorId,
        classId: classId,
        detectedName: detectedName,
        detectedDate: detectedDate,
        completedAt: completedAt,
        ocrConfidence: ocrConfidence,
        fieldConfidence: fieldConfidence,
        status: status,
        rejectionReason: rejectionReason,
        appliedEntityType: appliedEntityType,
        appliedEntityId: appliedEntityId,
      );

  static DateTime? _parseDate(dynamic value) {
    final raw = safeStringOrNull(value);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static String? _formatDate(DateTime? value) => value?.toIso8601String();

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
