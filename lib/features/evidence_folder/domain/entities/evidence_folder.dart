import 'package:equatable/equatable.dart';

import 'evidence_section.dart';

/// Representa el estado general de la carpeta de evidencias del club.
class EvidenceFolder extends Equatable {
  /// UUID de la carpeta anual (annual_folder_id). Necesario para operaciones
  /// de subida, envío y eliminación contra los endpoints de AnnualFolders.
  final String folderId;

  final String id;
  final String name;
  final String? description;

  /// Si [isOpen] es false, el campo local ha cerrado la carpeta y ninguna
  /// modificación es posible desde la app del club.
  final bool isOpen;

  final int totalPoints;
  final double totalPercentage;
  final List<EvidenceSection> sections;

  // ── Scoring (evaluación) ────────────────────────────────────────────────────

  /// Puntos obtenidos según la evaluación del backend (server-authoritative).
  /// Puede diferir del cómputo local cuando el evaluador asigna puntos parciales.
  /// Null si el backend aún no retorna este campo.
  final int? totalEarnedPoints;

  /// Puntos máximos posibles según el backend (server-authoritative).
  /// Null si el backend aún no retorna este campo.
  final int? totalMaxPoints;

  /// Porcentaje de progreso calculado por el backend (0.0 – 100.0).
  /// Null si el backend aún no retorna este campo.
  final double? progressPercentage;

  /// Fecha en que la carpeta fue evaluada completamente.
  final DateTime? evaluatedAt;

  /// Estado de la carpeta: open, submitted, under_evaluation, evaluated, closed.
  /// Complementa [isOpen] con estados más granulares del proceso de evaluación.
  final String? status;

  const EvidenceFolder({
    required this.folderId,
    required this.id,
    required this.name,
    this.description,
    required this.isOpen,
    required this.totalPoints,
    required this.totalPercentage,
    required this.sections,
    this.totalEarnedPoints,
    this.totalMaxPoints,
    this.progressPercentage,
    this.evaluatedAt,
    this.status,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// Puntos ganados: prioriza el valor server-authoritative del backend;
  /// cae al cómputo local sumando secciones validadas si el backend no lo envía.
  int get earnedPoints =>
      totalEarnedPoints ?? sections.fold(0, (sum, s) => sum + s.earnedPoints);

  /// Puntos máximos: prioriza el valor del backend; cae a [totalPoints].
  int get maxPoints => totalMaxPoints ?? totalPoints;

  /// Porcentaje completado global (0.0 – 1.0).
  /// Usa [progressPercentage] del backend si está disponible (ya en 0–100, se
  /// convierte a ratio). De lo contrario computa desde los puntos.
  double get completionRatio {
    if (progressPercentage != null) return progressPercentage! / 100.0;
    return maxPoints == 0 ? 0 : earnedPoints / maxPoints;
  }

  /// True si la carpeta fue evaluada (tiene fecha de evaluación o status evaluated).
  bool get isEvaluated => evaluatedAt != null || status == 'evaluated';

  /// True si la carpeta está bajo evaluación activa.
  bool get isUnderEvaluation => status == 'under_evaluation';

  /// Número de secciones en estado [EvidenceSectionStatus.validated].
  int get validatedCount =>
      sections.where((s) => s.status == EvidenceSectionStatus.validated).length;

  /// Número de secciones en estado [EvidenceSectionStatus.submitted] o
  /// [EvidenceSectionStatus.preapprovedLf].
  int get submittedCount => sections
      .where((s) =>
          s.status == EvidenceSectionStatus.submitted ||
          s.status == EvidenceSectionStatus.preapprovedLf)
      .length;

  @override
  List<Object?> get props => [
        folderId,
        id,
        name,
        description,
        isOpen,
        totalPoints,
        totalPercentage,
        sections,
        totalEarnedPoints,
        totalMaxPoints,
        progressPercentage,
        evaluatedAt,
        status,
      ];
}
