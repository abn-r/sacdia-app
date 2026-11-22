import 'package:equatable/equatable.dart';
import 'completion_status_json.dart';
import 'certification_status_json.dart';
import '../../domain/entities/certification_progress.dart';
import '../../domain/entities/certification_requirement.dart';
import '../../domain/entities/certification_status.dart';

/// Modelo de progreso de sección para la capa de datos
class SectionProgressModel extends Equatable {
  final int sectionId;
  final String sectionName;
  final bool completed;
  final DateTime? completionDate;
  final CertificationRequirementStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? lastReviewComment;
  final bool required;
  final bool hasDraft;

  const SectionProgressModel({
    required this.sectionId,
    required this.sectionName,
    required this.completed,
    this.completionDate,
    this.status = CertificationRequirementStatus.draft,
    this.submittedAt,
    this.reviewedAt,
    this.lastReviewComment,
    this.required = true,
    this.hasDraft = false,
  });

  /// Crea una instancia desde JSON
  factory SectionProgressModel.fromJson(Map<String, dynamic> json) {
    // Un servidor anterior al rediseño solo manda `completed`.
    final rawStatus = json['status'] as String?;
    final completed = json['completed'] as bool? ?? rawStatus == 'APPROVED';
    return SectionProgressModel(
      sectionId: (json['section_id'] ?? json['id']) as int,
      sectionName: json['section_name'] as String? ?? json['name'] as String,
      completed: completed,
      completionDate: json['completion_date'] != null
          ? DateTime.parse(json['completion_date'] as String)
          : null,
      status: rawStatus == null && completed
          ? CertificationRequirementStatus.approved
          : certificationRequirementStatusFromWire(rawStatus),
      submittedAt: certificationDateFromJson(json['submitted_at']),
      reviewedAt: certificationDateFromJson(json['reviewed_at']),
      lastReviewComment: json['last_review_comment'] as String?,
      required: json['required'] as bool? ?? true,
      hasDraft: rawStatus == 'DRAFT',
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'section_id': sectionId,
      'section_name': sectionName,
      'completed': completed,
      'completion_date': completionDate?.toIso8601String(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  SectionProgress toEntity() {
    return SectionProgress(
      sectionId: sectionId,
      sectionName: sectionName,
      completed: completed,
      completionDate: completionDate,
      status: status,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      lastReviewComment: lastReviewComment,
      required: required,
      hasDraft: hasDraft,
    );
  }

  @override
  List<Object?> get props => [
        sectionId,
        sectionName,
        completed,
        completionDate,
        status,
        submittedAt,
        reviewedAt,
        lastReviewComment,
        required,
        hasDraft,
      ];
}

/// Modelo de progreso de módulo para la capa de datos
class ModuleProgressModel extends Equatable {
  final int moduleId;
  final String moduleName;
  final List<SectionProgressModel> sections;

  const ModuleProgressModel({
    required this.moduleId,
    required this.moduleName,
    this.sections = const [],
  });

  /// Crea una instancia desde JSON
  factory ModuleProgressModel.fromJson(Map<String, dynamic> json) {
    return ModuleProgressModel(
      moduleId: (json['module_id'] ?? json['id']) as int,
      moduleName: json['module_name'] as String? ?? json['name'] as String,
      sections: (json['sections'] as List<dynamic>?)
              ?.map((s) =>
                  SectionProgressModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'module_id': moduleId,
      'module_name': moduleName,
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  ModuleProgress toEntity() {
    return ModuleProgress(
      moduleId: moduleId,
      moduleName: moduleName,
      sections: sections.map((s) => s.toEntity()).toList(),
    );
  }

  @override
  List<Object?> get props => [moduleId, moduleName, sections];
}

/// Modelo de progreso completo de un usuario en una certificación para la capa de datos
class CertificationProgressModel extends Equatable {
  final int enrollmentId;
  final int certificationId;
  final String certificationName;
  final double progressPercentage;
  final String completionStatus;
  final DateTime enrollmentDate;
  final List<ModuleProgressModel> modules;
  final CertificationEnrollmentStatus status;
  final DateTime? certifiedAt;
  final CertificationSummary? summary;
  final String? certificateUrl;

  const CertificationProgressModel({
    required this.enrollmentId,
    required this.certificationId,
    required this.certificationName,
    required this.progressPercentage,
    required this.completionStatus,
    required this.enrollmentDate,
    this.modules = const [],
    this.status = CertificationEnrollmentStatus.inProgress,
    this.certifiedAt,
    this.summary,
    this.certificateUrl,
  });

  /// Crea una instancia desde JSON
  factory CertificationProgressModel.fromJson(Map<String, dynamic> json) {
    return CertificationProgressModel(
      enrollmentId: (json['enrollment_id'] ?? json['id']) as int,
      certificationId: json['certification_id'] as int,
      certificationName: (json['certification_name'] ??
          (json['certifications'] as Map<String, dynamic>?)?['name'] ??
          '') as String,
      progressPercentage: ((json['progress_percentage'] ??
              json['progressPercentage'] ??
              0) as num)
          .toDouble(),
      completionStatus: completionStatusFromJson(json['completion_status']),
      enrollmentDate: DateTime.parse(json['enrollment_date'] as String),
      modules: (json['modules'] as List<dynamic>?)
              ?.map((m) =>
                  ModuleProgressModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      status: certificationEnrollmentStatusFromJson(json),
      certifiedAt: certificationDateFromJson(json['certified_at']),
      summary: certificationSummaryFromJson(json['summary']),
      certificateUrl: json['certificate_url'] as String?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      'certification_id': certificationId,
      'certification_name': certificationName,
      'progress_percentage': progressPercentage,
      'completion_status': completionStatus,
      'enrollment_date': enrollmentDate.toIso8601String(),
      'modules': modules.map((m) => m.toJson()).toList(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  CertificationProgress toEntity() {
    return CertificationProgress(
      enrollmentId: enrollmentId,
      certificationId: certificationId,
      certificationName: certificationName,
      progressPercentage: progressPercentage,
      completionStatus: completionStatus,
      enrollmentDate: enrollmentDate,
      modules: modules.map((m) => m.toEntity()).toList(),
      status: status,
      certifiedAt: certifiedAt,
      summary: summary,
      certificateUrl: certificateUrl,
    );
  }

  /// Crea una copia con campos actualizados
  CertificationProgressModel copyWith({
    int? enrollmentId,
    int? certificationId,
    String? certificationName,
    double? progressPercentage,
    String? completionStatus,
    DateTime? enrollmentDate,
    List<ModuleProgressModel>? modules,
    CertificationEnrollmentStatus? status,
  }) {
    return CertificationProgressModel(
      enrollmentId: enrollmentId ?? this.enrollmentId,
      certificationId: certificationId ?? this.certificationId,
      certificationName: certificationName ?? this.certificationName,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      completionStatus: completionStatus ?? this.completionStatus,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      modules: modules ?? this.modules,
      status: status ?? this.status,
      certifiedAt: certifiedAt,
      summary: summary,
      certificateUrl: certificateUrl,
    );
  }

  @override
  List<Object?> get props => [
        enrollmentId,
        certificationId,
        certificationName,
        progressPercentage,
        completionStatus,
        enrollmentDate,
        modules,
        status,
        certifiedAt,
        summary,
        certificateUrl,
      ];
}
