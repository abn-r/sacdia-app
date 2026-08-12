import 'package:equatable/equatable.dart';

import '../../domain/entities/certification_evidence.dart';

Map<String, String> _stringHeaders(Map<String, dynamic>? json) {
  if (json == null) return const {};
  return json.map((key, value) => MapEntry(key, value.toString()));
}

/// Modelo del ticket de subida de evidencia de requisito.
class CertificationEvidenceUploadTicketModel extends Equatable {
  final int evidenceId;
  final String uploadUrl;
  final String objectKey;
  final int expiresIn;
  final Map<String, String> requiredHeaders;

  const CertificationEvidenceUploadTicketModel({
    required this.evidenceId,
    required this.uploadUrl,
    required this.objectKey,
    required this.expiresIn,
    this.requiredHeaders = const {},
  });

  factory CertificationEvidenceUploadTicketModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CertificationEvidenceUploadTicketModel(
      evidenceId: json['evidence_id'] as int,
      uploadUrl: json['upload_url'] as String,
      objectKey: json['object_key'] as String,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      requiredHeaders:
          _stringHeaders(json['required_headers'] as Map<String, dynamic>?),
    );
  }

  CertificationEvidenceUploadTicket toEntity() =>
      CertificationEvidenceUploadTicket(
        evidenceId: evidenceId,
        uploadUrl: uploadUrl,
        objectKey: objectKey,
        expiresIn: expiresIn,
        requiredHeaders: requiredHeaders,
      );

  @override
  List<Object?> get props =>
      [evidenceId, uploadUrl, objectKey, expiresIn, requiredHeaders];
}

/// Modelo de evidencia confirmada.
class CertificationEvidenceModel extends Equatable {
  final int evidenceId;
  final String objectKey;
  final String originalFilename;
  final String mimeType;
  final int sizeBytes;
  final String uploadStatus;
  final DateTime? confirmedAt;

  const CertificationEvidenceModel({
    required this.evidenceId,
    required this.objectKey,
    required this.originalFilename,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadStatus,
    this.confirmedAt,
  });

  factory CertificationEvidenceModel.fromJson(Map<String, dynamic> json) {
    return CertificationEvidenceModel(
      evidenceId: json['evidence_id'] as int,
      objectKey: json['object_key'] as String? ?? '',
      originalFilename: json['original_filename'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      uploadStatus: json['upload_status'] as String? ?? 'PENDING_UPLOAD',
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'] as String)
          : null,
    );
  }

  CertificationEvidence toEntity() => CertificationEvidence(
        evidenceId: evidenceId,
        objectKey: objectKey,
        originalFilename: originalFilename,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        uploadStatus: uploadStatus,
        confirmedAt: confirmedAt,
      );

  @override
  List<Object?> get props => [
        evidenceId,
        objectKey,
        originalFilename,
        mimeType,
        sizeBytes,
        uploadStatus,
        confirmedAt,
      ];
}

/// Modelo del ticket de subida del comprobante de junta.
class CertificationCloseoutUploadTicketModel extends Equatable {
  final int closeoutEvidenceId;
  final String uploadUrl;
  final String objectKey;
  final int expiresIn;
  final Map<String, String> requiredHeaders;

  const CertificationCloseoutUploadTicketModel({
    required this.closeoutEvidenceId,
    required this.uploadUrl,
    required this.objectKey,
    required this.expiresIn,
    this.requiredHeaders = const {},
  });

  factory CertificationCloseoutUploadTicketModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CertificationCloseoutUploadTicketModel(
      closeoutEvidenceId: json['closeout_evidence_id'] as int,
      uploadUrl: json['upload_url'] as String,
      objectKey: json['object_key'] as String,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      requiredHeaders:
          _stringHeaders(json['required_headers'] as Map<String, dynamic>?),
    );
  }

  CertificationCloseoutUploadTicket toEntity() =>
      CertificationCloseoutUploadTicket(
        closeoutEvidenceId: closeoutEvidenceId,
        uploadUrl: uploadUrl,
        objectKey: objectKey,
        expiresIn: expiresIn,
        requiredHeaders: requiredHeaders,
      );

  @override
  List<Object?> get props => [
        closeoutEvidenceId,
        uploadUrl,
        objectKey,
        expiresIn,
        requiredHeaders,
      ];
}

/// Modelo del comprobante de junta confirmado.
class CertificationCloseoutEvidenceModel extends Equatable {
  final int closeoutEvidenceId;
  final String uploadStatus;
  final String reviewStatus;

  const CertificationCloseoutEvidenceModel({
    required this.closeoutEvidenceId,
    required this.uploadStatus,
    required this.reviewStatus,
  });

  factory CertificationCloseoutEvidenceModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CertificationCloseoutEvidenceModel(
      closeoutEvidenceId: json['closeout_evidence_id'] as int,
      uploadStatus: json['upload_status'] as String? ?? 'PENDING_UPLOAD',
      reviewStatus: json['review_status'] as String? ?? 'PENDING',
    );
  }

  CertificationCloseoutEvidence toEntity() => CertificationCloseoutEvidence(
        closeoutEvidenceId: closeoutEvidenceId,
        uploadStatus: uploadStatus,
        reviewStatus: reviewStatus,
      );

  @override
  List<Object?> get props => [closeoutEvidenceId, uploadStatus, reviewStatus];
}

/// Modelo del resultado de `submitFinal`.
class CertificationSubmitFinalResultModel extends Equatable {
  final int enrollmentId;
  final String status;

  const CertificationSubmitFinalResultModel({
    required this.enrollmentId,
    required this.status,
  });

  factory CertificationSubmitFinalResultModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CertificationSubmitFinalResultModel(
      enrollmentId: json['enrollment_id'] as int,
      status: json['status'] as String? ?? '',
    );
  }

  CertificationSubmitFinalResult toEntity() => CertificationSubmitFinalResult(
        enrollmentId: enrollmentId,
        status: status,
      );

  @override
  List<Object?> get props => [enrollmentId, status];
}
