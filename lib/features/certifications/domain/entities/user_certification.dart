import 'package:equatable/equatable.dart';

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
  });

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
      ];
}
