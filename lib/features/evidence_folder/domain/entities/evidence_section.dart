import 'package:equatable/equatable.dart';

import 'evidence_file.dart';

/// Estado del flujo de evidencias de una sección.
enum EvidenceSectionStatus {
  /// El club aún no ha enviado evidencias para validación.
  pendiente,

  /// El club envió las evidencias y espera revisión del campo local.
  enviado,

  /// El campo local validó (o rechazó) la sección.
  validado,

  /// La sección está siendo evaluada por el evaluador del campo.
  underEvaluation,

  /// La sección fue evaluada y tiene puntuación asignada.
  evaluated,
}

/// Parsea el string que llega desde la API al enum correspondiente.
EvidenceSectionStatus evidenceSectionStatusFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'enviado':
      return EvidenceSectionStatus.enviado;
    case 'validado':
      return EvidenceSectionStatus.validado;
    case 'under_evaluation':
    case 'underevaluation':
      return EvidenceSectionStatus.underEvaluation;
    case 'evaluated':
      return EvidenceSectionStatus.evaluated;
    default:
      return EvidenceSectionStatus.pendiente;
  }
}

/// Convierte el enum a string para enviar a la API.
String evidenceSectionStatusToString(EvidenceSectionStatus status) {
  switch (status) {
    case EvidenceSectionStatus.enviado:
      return 'enviado';
    case EvidenceSectionStatus.validado:
      return 'validado';
    case EvidenceSectionStatus.underEvaluation:
      return 'under_evaluation';
    case EvidenceSectionStatus.evaluated:
      return 'evaluated';
    case EvidenceSectionStatus.pendiente:
      return 'pendiente';
  }
}

/// Una sección dentro de la [EvidenceFolder].
///
/// Cada sección tiene un nombre, peso en puntos y porcentaje, un límite de
/// archivos configurado por el campo local, y un flujo de estado propio.
class EvidenceSection extends Equatable {
  final String id;
  final String name;
  final String? description;

  /// Valor en puntos que otorga esta sección al validarse.
  final int pointValue;

  /// Contribución porcentual de esta sección al total de la carpeta.
  final double percentage;

  /// Límite máximo de archivos de evidencia (configurable por campo local).
  final int maxFiles;

  final EvidenceSectionStatus status;

  final List<EvidenceFile> files;

  // ── Trazabilidad ────────────────────────────────────────────────────────────

  final String? submittedByName;
  final DateTime? submittedAt;

  final String? validatedByName;
  final DateTime? validatedAt;

  /// Puntos efectivamente ganados en esta sección (0 hasta que sea validada).
  final int earnedPoints;

  // ── Evaluación (scoring) ─────────────────────────────────────────────────

  /// Nombre del evaluador que puntuó esta sección (null si aún no fue evaluada).
  final String? evaluatedByName;

  /// Fecha en que se registró la evaluación (null si no evaluada).
  final DateTime? evaluatedAt;

  /// Notas del evaluador sobre esta sección (null si no hay notas).
  final String? evaluationNotes;

  const EvidenceSection({
    required this.id,
    required this.name,
    this.description,
    required this.pointValue,
    required this.percentage,
    this.maxFiles = 10,
    required this.status,
    this.files = const [],
    this.submittedByName,
    this.submittedAt,
    this.validatedByName,
    this.validatedAt,
    this.earnedPoints = 0,
    this.evaluatedByName,
    this.evaluatedAt,
    this.evaluationNotes,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// Slots de archivos restantes.
  int get remainingSlots => (maxFiles - files.length).clamp(0, maxFiles);

  /// El club puede subir o eliminar archivos sólo cuando está pendiente.
  bool get canUpload => status == EvidenceSectionStatus.pendiente;

  /// El club puede enviar a validación cuando tiene archivos y está pendiente.
  bool get canSubmit =>
      status == EvidenceSectionStatus.pendiente && files.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        pointValue,
        percentage,
        maxFiles,
        status,
        files,
        submittedByName,
        submittedAt,
        validatedByName,
        validatedAt,
        earnedPoints,
        evaluatedByName,
        evaluatedAt,
        evaluationNotes,
      ];
}
