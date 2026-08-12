import 'package:equatable/equatable.dart';

/// Ticket de subida devuelto por `POST .../evidences/presign`.
///
/// Contiene la URL firmada de R2 a la que se debe hacer el `PUT` directo
/// con los bytes del archivo, más los headers requeridos (`Content-Type`).
class CertificationEvidenceUploadTicket extends Equatable {
  final int evidenceId;
  final String uploadUrl;
  final String objectKey;
  final int expiresIn;
  final Map<String, String> requiredHeaders;

  const CertificationEvidenceUploadTicket({
    required this.evidenceId,
    required this.uploadUrl,
    required this.objectKey,
    required this.expiresIn,
    this.requiredHeaders = const {},
  });

  @override
  List<Object?> get props =>
      [evidenceId, uploadUrl, objectKey, expiresIn, requiredHeaders];
}

/// Evidencia confirmada — resultado de `POST .../evidences/confirm`.
class CertificationEvidence extends Equatable {
  final int evidenceId;
  final String objectKey;
  final String originalFilename;
  final String mimeType;
  final int sizeBytes;
  final String uploadStatus;
  final DateTime? confirmedAt;

  const CertificationEvidence({
    required this.evidenceId,
    required this.objectKey,
    required this.originalFilename,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadStatus,
    this.confirmedAt,
  });

  bool get isConfirmed => uploadStatus == 'CONFIRMED';
  bool get isImage => mimeType.startsWith('image/');

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

/// Ticket de subida del comprobante de junta —
/// `POST .../closeout-evidence/presign`.
class CertificationCloseoutUploadTicket extends Equatable {
  final int closeoutEvidenceId;
  final String uploadUrl;
  final String objectKey;
  final int expiresIn;
  final Map<String, String> requiredHeaders;

  const CertificationCloseoutUploadTicket({
    required this.closeoutEvidenceId,
    required this.uploadUrl,
    required this.objectKey,
    required this.expiresIn,
    this.requiredHeaders = const {},
  });

  @override
  List<Object?> get props => [
        closeoutEvidenceId,
        uploadUrl,
        objectKey,
        expiresIn,
        requiredHeaders,
      ];
}

/// Comprobante de junta confirmado —
/// `POST .../closeout-evidence/confirm`.
class CertificationCloseoutEvidence extends Equatable {
  final int closeoutEvidenceId;
  final String uploadStatus;
  final String reviewStatus;

  const CertificationCloseoutEvidence({
    required this.closeoutEvidenceId,
    required this.uploadStatus,
    required this.reviewStatus,
  });

  bool get isConfirmed => uploadStatus == 'CONFIRMED';

  @override
  List<Object?> get props => [closeoutEvidenceId, uploadStatus, reviewStatus];
}

/// Resultado de `POST .../submit-final`: nuevo estado de la inscripción.
class CertificationSubmitFinalResult extends Equatable {
  final int enrollmentId;
  final String status;

  const CertificationSubmitFinalResult({
    required this.enrollmentId,
    required this.status,
  });

  @override
  List<Object?> get props => [enrollmentId, status];
}
