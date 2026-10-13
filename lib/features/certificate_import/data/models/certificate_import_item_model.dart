export '../../domain/entities/certificate_import_item.dart';

import 'package:equatable/equatable.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/certificate_import_item.dart';

class CertificateImportItemModel extends Equatable {
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
  final int? sourcePage;
  final String? sourceFileId;
  final CertificateImportHonorRef? honor;
  final CertificateImportClassRef? classRef;
  final CertificateImportInstructorRef? instructor;
  final int revision;

  const CertificateImportItemModel({
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
    this.revision = 0,
  });

  factory CertificateImportItemModel.fromJson(Map<String, dynamic> json) {
    final rawFieldConfidence = json['field_confidence'];
    final nestedClass = json['class'];
    final nestedAssetCode =
        nestedClass is Map<String, dynamic> ? nestedClass['asset_code'] : null;
    return CertificateImportItemModel(
      id: safeString(json['item_id'] ?? json['id']),
      batchId: safeStringOrNull(json['batch_id']),
      type: parseItemType(safeString(json['item_type'] ?? json['type'])),
      honorId: safeIntOrNull(json['honor_id']),
      classId: safeIntOrNull(json['class_id']),
      classAssetCode: safeStringOrNull(
        json['class_asset_code'] ?? nestedAssetCode,
      ),
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
      sourcePage: _positive(json['source_page']),
      sourceFileId: safeStringOrNull(json['source_file_id']),
      honor: _parseHonor(json['honor']),
      classRef: _parseClass(nestedClass),
      instructor: _parseInstructor(json['instructor']),
      // Tolerant: an API without it means a row nobody has saved.
      revision: _positive(json['revision']) ?? 0,
    );
  }

  /// R6: every nested block may be absent or `null`; that means "no data".
  static CertificateImportHonorRef? _parseHonor(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = safeIntOrNull(raw['honor_id']);
    final name = safeStringOrNull(raw['name']);
    if (id == null || name == null) return null;
    final category = raw['category'];
    return CertificateImportHonorRef(
      id: id,
      name: name,
      categoryId:
          category is Map ? safeIntOrNull(category['honor_category_id']) : null,
      categoryName: category is Map ? safeStringOrNull(category['name']) : null,
    );
  }

  static CertificateImportClassRef? _parseClass(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = safeIntOrNull(raw['class_id']);
    final name = safeStringOrNull(raw['name']);
    if (id == null || name == null) return null;
    final clubType = raw['club_type'];
    return CertificateImportClassRef(
      id: id,
      name: name,
      assetCode: safeStringOrNull(raw['asset_code']),
      clubTypeId:
          clubType is Map ? safeIntOrNull(clubType['club_type_id']) : null,
      clubTypeName: clubType is Map ? safeStringOrNull(clubType['name']) : null,
    );
  }

  static CertificateImportInstructorRef? _parseInstructor(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final name = safeStringOrNull(raw['display_name']);
    if (name == null) return null;
    return CertificateImportInstructorRef(
      isUser: raw['kind'] == 'USER',
      displayName: name,
      userId: safeStringOrNull(raw['user_id']),
      photoUrl: safeStringOrNull(raw['photo_url']),
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
        'class_asset_code': classAssetCode,
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
        'source_page': sourcePage,
        'source_file_id': sourceFileId,
        'revision': revision,
      };

  CertificateImportItem toEntity() => CertificateImportItem(
        id: id,
        batchId: batchId,
        type: type,
        honorId: honorId,
        classId: classId,
        classAssetCode: classAssetCode,
        detectedName: detectedName,
        detectedDate: detectedDate,
        completedAt: completedAt,
        ocrConfidence: ocrConfidence,
        fieldConfidence: fieldConfidence,
        status: status,
        rejectionReason: rejectionReason,
        appliedEntityType: appliedEntityType,
        appliedEntityId: appliedEntityId,
        sourcePage: sourcePage,
        sourceFileId: sourceFileId,
        honor: honor,
        classRef: classRef,
        instructor: instructor,
        revision: revision,
      );

  /// `completed_at` and `detected_date` are calendar days. Read them as that
  /// day, not as a UTC instant: `2021-10-15T00:00:00.000Z` shown in local
  /// time (America/Mexico_City) would become 14 Oct.
  static DateTime? _parseDate(dynamic value) =>
      SacDateFormatter.tryParseCalendarDate(safeStringOrNull(value));

  static String? _formatDate(DateTime? value) => value?.toIso8601String();

  /// R6: a missing, null or non-positive value means "no data".
  static int? _positive(dynamic value) {
    final parsed = safeIntOrNull(value);
    return parsed != null && parsed >= 1 ? parsed : null;
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
        revision,
      ];
}
