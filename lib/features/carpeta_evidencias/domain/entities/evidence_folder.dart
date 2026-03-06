import 'package:equatable/equatable.dart';

import 'evidence_section.dart';

/// Representa el estado general de la carpeta de evidencias del club.
class EvidenceFolder extends Equatable {
  final String id;
  final String name;
  final String? description;

  /// Si [isOpen] es false, el campo local ha cerrado la carpeta y ninguna
  /// modificación es posible desde la app del club.
  final bool isOpen;

  final int totalPoints;
  final double totalPercentage;
  final List<EvidenceSection> sections;

  const EvidenceFolder({
    required this.id,
    required this.name,
    this.description,
    required this.isOpen,
    required this.totalPoints,
    required this.totalPercentage,
    required this.sections,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// Puntos ganados sumando las secciones ya validadas.
  int get earnedPoints =>
      sections.fold(0, (sum, s) => sum + s.earnedPoints);

  /// Porcentaje completado global (0.0 – 1.0) considerando sólo validadas.
  double get completionRatio =>
      totalPoints == 0 ? 0 : earnedPoints / totalPoints;

  /// Número de secciones en estado [EvidenceSectionStatus.validado].
  int get validatedCount =>
      sections.where((s) => s.status == EvidenceSectionStatus.validado).length;

  /// Número de secciones en estado [EvidenceSectionStatus.enviado].
  int get submittedCount =>
      sections.where((s) => s.status == EvidenceSectionStatus.enviado).length;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        isOpen,
        totalPoints,
        totalPercentage,
        sections,
      ];
}
