import 'package:equatable/equatable.dart';

import 'evidence_file.dart';
import 'union_evaluation_decision.dart';

/// Estado almacenado de una sección de evidencias.
///
/// El servidor es la fuente de verdad — este enum refleja exactamente los
/// valores del tipo Postgres `annual_folder_section_status_enum`. El cliente
/// NO debe derivar este valor; debe leer el campo `status` del JSON.
///
/// Valores del backend:
///   PENDING | SUBMITTED | PREAPPROVED_LF | VALIDATED | REJECTED
enum EvidenceSectionStatus {
  /// La sección aún no fue enviada por el club. Valor backend: `PENDING`.
  pending,

  /// El club envió las evidencias y esperan revisión del campo local. Valor backend: `SUBMITTED`.
  submitted,

  /// El campo local pre-aprobó la sección; pendiente de validación de la unión. Valor backend: `PREAPPROVED_LF`.
  preapprovedLf,

  /// La sección fue validada definitivamente. Valor backend: `VALIDATED`.
  validated,

  /// La sección fue rechazada; el club puede reenviar. Valor backend: `REJECTED`.
  rejected,
}

extension EvidenceSectionStatusX on EvidenceSectionStatus {
  /// Deserializa el string exacto que llega desde el backend.
  ///
  /// Si el valor es desconocido (rollout parcial, valor legacy), se usa
  /// [EvidenceSectionStatus.pending] como fallback seguro.
  static EvidenceSectionStatus fromJson(String? value) {
    switch (value?.toUpperCase()) {
      case 'SUBMITTED':
        return EvidenceSectionStatus.submitted;
      case 'PREAPPROVED_LF':
        return EvidenceSectionStatus.preapprovedLf;
      case 'VALIDATED':
        return EvidenceSectionStatus.validated;
      case 'REJECTED':
        return EvidenceSectionStatus.rejected;
      case 'PENDING':
      default:
        return EvidenceSectionStatus.pending;
    }
  }

  /// Serializa al string canónico del backend.
  String toJson() {
    switch (this) {
      case EvidenceSectionStatus.pending:
        return 'PENDING';
      case EvidenceSectionStatus.submitted:
        return 'SUBMITTED';
      case EvidenceSectionStatus.preapprovedLf:
        return 'PREAPPROVED_LF';
      case EvidenceSectionStatus.validated:
        return 'VALIDATED';
      case EvidenceSectionStatus.rejected:
        return 'REJECTED';
    }
  }
}

/// Una sección dentro de la [EvidenceFolder].
///
/// Cada sección tiene un nombre, peso en puntos y porcentaje, un límite de
/// archivos configurado por el campo local, y un flujo de estado propio.
///
/// A partir del rework de annual-folders-ownership, el [status] se lee
/// directamente del servidor (columna STORED en Postgres). No se deriva
/// en el cliente.
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

  /// Estado almacenado de la sección. Fuente de verdad: backend.
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

  // ── Aprobación de campo local (LF) ─────────────────────────────────────────

  /// Nombre del actor del campo local que pre-aprobó esta sección.
  final String? lfApproverName;

  /// Fecha en que el campo local registró la pre-aprobación.
  final DateTime? lfApprovedAt;

  // ── Aprobación de unión ─────────────────────────────────────────────────────

  /// Nombre del actor de la unión que validó o rechazó definitivamente.
  final String? unionApproverName;

  /// Fecha en que la unión registró su decisión.
  final DateTime? unionApprovedAt;

  /// Decisión final de la unión sobre esta sección.
  final UnionEvaluationDecision? unionDecision;

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
    this.lfApproverName,
    this.lfApprovedAt,
    this.unionApproverName,
    this.unionApprovedAt,
    this.unionDecision,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// Slots de archivos restantes.
  int get remainingSlots => (maxFiles - files.length).clamp(0, maxFiles);

  /// El club puede subir o eliminar archivos cuando está pendiente o rechazado.
  bool get canUpload =>
      status == EvidenceSectionStatus.pending ||
      status == EvidenceSectionStatus.rejected;

  /// El club puede enviar a validación cuando tiene archivos y está pendiente o rechazado.
  bool get canSubmit =>
      (status == EvidenceSectionStatus.pending ||
          status == EvidenceSectionStatus.rejected) &&
      files.isNotEmpty;

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
        lfApproverName,
        lfApprovedAt,
        unionApproverName,
        unionApprovedAt,
        unionDecision,
      ];
}
