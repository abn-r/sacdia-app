import 'package:equatable/equatable.dart';

/// Progreso de una sección dentro de un módulo de certificación
class SectionProgress extends Equatable {
  final int sectionId;
  final String sectionName;
  final bool completed;
  final DateTime? completionDate;

  const SectionProgress({
    required this.sectionId,
    required this.sectionName,
    required this.completed,
    this.completionDate,
  });

  @override
  List<Object?> get props => [sectionId, sectionName, completed, completionDate];
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

  int get completedSections => sections.where((s) => s.completed).length;
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

  const CertificationProgress({
    required this.enrollmentId,
    required this.certificationId,
    required this.certificationName,
    required this.progressPercentage,
    required this.completionStatus,
    required this.enrollmentDate,
    this.modules = const [],
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
      ];
}
