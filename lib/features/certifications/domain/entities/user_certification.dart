import 'package:equatable/equatable.dart';

import 'certification_status.dart';

/// Entidad de inscripción de usuario en una certificación del dominio
class UserCertification extends Equatable {
  final int enrollmentId;
  final int certificationId;
  final String certificationName;
  final DateTime enrollmentDate;
  final String completionStatus;
  final double progressPercentage;
  final int modulesCompleted;
  final int modulesTotal;
  final bool active;

  /// Estado de la inscripción (`status` del backend).
  final CertificationEnrollmentStatus status;
  final DateTime? certifiedAt;

  /// Conteo de requisitos por estado; nulo si el backend no lo envía.
  final CertificationSummary? summary;

  /// Enlace de descarga del certificado, si ya se otorgó.
  final String? certificateUrl;

  const UserCertification({
    required this.enrollmentId,
    required this.certificationId,
    required this.certificationName,
    required this.enrollmentDate,
    required this.completionStatus,
    required this.progressPercentage,
    required this.modulesCompleted,
    required this.modulesTotal,
    required this.active,
    this.status = CertificationEnrollmentStatus.inProgress,
    this.certifiedAt,
    this.summary,
    this.certificateUrl,
  });

  /// La persona sigue inscrita: una inscripción retirada no cuenta.
  bool get isEnrolled => active && status.isEnrolled;

  @override
  List<Object?> get props => [
        enrollmentId,
        certificationId,
        certificationName,
        enrollmentDate,
        completionStatus,
        progressPercentage,
        modulesCompleted,
        modulesTotal,
        active,
        status,
        certifiedAt,
        summary,
        certificateUrl,
      ];
}
