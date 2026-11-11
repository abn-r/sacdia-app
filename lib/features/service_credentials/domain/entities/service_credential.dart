import 'package:equatable/equatable.dart';

/// Tipo de constancia. Hoy solo existe la de consejería.
const String kCounselorTrainingType = 'COUNSELOR_TRAINING';

/// Estado de revisión. Desconocido = [unknown] (se trata como «en revisión»
/// para no ofrecer acciones que el servidor no ha confirmado).
enum ServiceCredentialStatus {
  pendingReview('PENDING_REVIEW'),
  approved('APPROVED'),
  rejected('REJECTED'),
  unknown('');

  const ServiceCredentialStatus(this.apiValue);

  final String apiValue;

  static ServiceCredentialStatus parse(Object? raw) {
    final value = raw?.toString().trim().toUpperCase();
    for (final v in values) {
      if (v != unknown && v.apiValue == value) return v;
    }
    return unknown;
  }
}

/// Estado de la subida del archivo.
enum ServiceCredentialUploadStatus {
  pendingUpload('PENDING_UPLOAD'),
  confirmed('CONFIRMED'),
  unknown('');

  const ServiceCredentialUploadStatus(this.apiValue);

  final String apiValue;

  static ServiceCredentialUploadStatus parse(Object? raw) {
    final value = raw?.toString().trim().toUpperCase();
    for (final v in values) {
      if (v != unknown && v.apiValue == value) return v;
    }
    return unknown;
  }
}

/// Constancia propia (`/users/me/service-credentials`).
class ServiceCredential extends Equatable {
  const ServiceCredential({
    required this.id,
    this.type = kCounselorTrainingType,
    this.completedAt,
    this.status = ServiceCredentialStatus.unknown,
    this.uploadStatus = ServiceCredentialUploadStatus.unknown,
    this.decisionReason,
    this.reviewedAt,
    this.expiresAt,
    this.fileName,
    this.createdAt,
  });

  final String id;
  final String type;
  final DateTime? completedAt;
  final ServiceCredentialStatus status;
  final ServiceCredentialUploadStatus uploadStatus;

  /// Motivo del rechazo.
  final String? decisionReason;
  final DateTime? reviewedAt;
  final DateTime? expiresAt;
  final String? fileName;
  final DateTime? createdAt;

  bool get isApproved => status == ServiceCredentialStatus.approved;
  bool get isRejected => status == ServiceCredentialStatus.rejected;

  /// Espera revisión (también el estado desconocido: falla cerrado).
  bool get isPending => !isApproved && !isRejected;

  /// Se puede retirar mientras no esté aprobada.
  bool get canWithdraw => !isApproved;

  @override
  List<Object?> get props => [
        id,
        type,
        completedAt,
        status,
        uploadStatus,
        decisionReason,
        reviewedAt,
        expiresAt,
        fileName,
        createdAt,
      ];
}

/// Lo que la persona llena al subir: sin el archivo.
class ServiceCredentialDraft extends Equatable {
  const ServiceCredentialDraft({
    required this.completedAt,
  });

  final DateTime completedAt;

  @override
  List<Object?> get props => [completedAt];
}

/// Fase de [submit] para pintar el avance.
enum ServiceCredentialSubmitPhase { registering, uploading, confirming }
