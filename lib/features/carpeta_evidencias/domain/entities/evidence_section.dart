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
}

/// Parsea el string que llega desde la API al enum correspondiente.
EvidenceSectionStatus evidenceSectionStatusFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'enviado':
      return EvidenceSectionStatus.enviado;
    case 'validado':
      return EvidenceSectionStatus.validado;
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
      ];
}
