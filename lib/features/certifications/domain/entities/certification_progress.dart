import 'package:equatable/equatable.dart';

import 'certification_requirement.dart';
import 'certification_status.dart';

/// Progreso de una sección dentro de un módulo de certificación
class SectionProgress extends Equatable {
  final int sectionId;
  final String sectionName;
  final bool completed;
  final DateTime? completionDate;

  /// Estado del requisito (`NOT_STARTED`/`DRAFT` llegan como borrador).
  final CertificationRequirementStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? lastReviewComment;
  final bool required;

  /// Hay un borrador guardado (`DRAFT`), a diferencia de `NOT_STARTED`.
  final bool hasDraft;

  const SectionProgress({
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

/// Progreso de un módulo dentro de una certificación
class ModuleProgress extends Equatable {
  final int moduleId;
  final String moduleName;
  final List<SectionProgress> sections;

  const ModuleProgress({
    required this.moduleId,
    required this.moduleName,
    this.sections = const [],
  });

  int get completedSections => sections
      .where((s) => s.status == CertificationRequirementStatus.approved)
      .length;
  int get totalSections => sections.length;

  @override
  List<Object?> get props => [moduleId, moduleName, sections];
}

/// Entidad de progreso completo de un usuario en una certificación del dominio
class CertificationProgress extends Equatable {
  final int enrollmentId;
  final int certificationId;
  final String certificationName;
  final double progressPercentage;
  final String completionStatus;
  final DateTime enrollmentDate;
  final List<ModuleProgress> modules;

  /// Estado de la inscripción (`status` del backend).
  final CertificationEnrollmentStatus status;
  final DateTime? certifiedAt;

  /// Conteo de requisitos por estado; nulo si el backend no lo envía.
  final CertificationSummary? summary;
  final String? certificateUrl;

  const CertificationProgress({
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
