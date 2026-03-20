import 'package:equatable/equatable.dart';
import '../../domain/entities/user_certification.dart';

/// Modelo de inscripción de usuario en una certificación para la capa de datos
class UserCertificationModel extends Equatable {
  final int enrollmentId;
  final int certificationId;
  final String certificationName;
  final DateTime enrollmentDate;
  final String completionStatus;
  final double progressPercentage;
  final int modulesCompleted;
  final int modulesTotal;
  final bool active;

  const UserCertificationModel({
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

  /// Crea una instancia desde JSON
  factory UserCertificationModel.fromJson(Map<String, dynamic> json) {
    return UserCertificationModel(
      enrollmentId: (json['enrollment_id'] ?? json['id']) as int,
      certificationId: (json['certification_id']) as int,
      certificationName: (json['certification_name'] ??
          (json['certifications'] as Map<String, dynamic>?)?['name'] ??
          '') as String,
      enrollmentDate: DateTime.parse(json['enrollment_date'] as String),
      completionStatus: json['completion_status'] as String? ?? 'in_progress',
      progressPercentage:
          ((json['progress_percentage'] ?? json['progressPercentage'] ?? 0) as num)
              .toDouble(),
      modulesCompleted:
          (json['modules_completed'] ?? json['modulesCompleted'] ?? 0) as int,
      modulesTotal: (json['modules_total'] ?? json['modulesTotal'] ?? 0) as int,
      active: json['active'] as bool? ?? true,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      'certification_id': certificationId,
      'certification_name': certificationName,
      'enrollment_date': enrollmentDate.toIso8601String(),
      'completion_status': completionStatus,
      'progress_percentage': progressPercentage,
      'modules_completed': modulesCompleted,
      'modules_total': modulesTotal,
      'active': active,
    };
  }

  /// Convierte el modelo a entidad de dominio
  UserCertification toEntity() {
    return UserCertification(
      enrollmentId: enrollmentId,
      certificationId: certificationId,
      certificationName: certificationName,
      enrollmentDate: enrollmentDate,
      completionStatus: completionStatus,
      progressPercentage: progressPercentage,
      modulesCompleted: modulesCompleted,
      modulesTotal: modulesTotal,
      active: active,
    );
  }

  /// Crea una copia con campos actualizados
  UserCertificationModel copyWith({
    int? enrollmentId,
    int? certificationId,
    String? certificationName,
    DateTime? enrollmentDate,
    String? completionStatus,
    double? progressPercentage,
    int? modulesCompleted,
    int? modulesTotal,
    bool? active,
  }) {
    return UserCertificationModel(
      enrollmentId: enrollmentId ?? this.enrollmentId,
      certificationId: certificationId ?? this.certificationId,
      certificationName: certificationName ?? this.certificationName,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      completionStatus: completionStatus ?? this.completionStatus,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      modulesCompleted: modulesCompleted ?? this.modulesCompleted,
      modulesTotal: modulesTotal ?? this.modulesTotal,
      active: active ?? this.active,
    );
  }

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
