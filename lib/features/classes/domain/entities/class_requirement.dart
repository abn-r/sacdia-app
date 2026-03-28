import 'package:equatable/equatable.dart';

import 'requirement_evidence.dart';

/// Estado del flujo de validacion de un requerimiento de clase progresiva.
enum RequirementStatus {
  /// El miembro aun no ha enviado evidencias.
  pendiente,

  /// El miembro envio las evidencias y espera revision.
  enviado,

  /// El lider del club valido el requerimiento.
  validado,

  /// El lider rechazo el requerimiento; el miembro puede reenviar.
  rechazado,
}

/// Parsea el string que llega desde la API al enum correspondiente.
/// Soporta tanto valores legacy en español como el enum inglés actual.
RequirementStatus requirementStatusFromString(String? value) {
  switch (value?.toUpperCase()) {
    case 'ENVIADO':
    case 'SUBMITTED':
      return RequirementStatus.enviado;
    case 'VALIDADO':
    case 'VALIDATED':
      return RequirementStatus.validado;
    case 'RECHAZADO':
    case 'REJECTED':
      return RequirementStatus.rechazado;
    default:
      return RequirementStatus.pendiente;
  }
}

/// Convierte el enum a string para enviar a la API.
String requirementStatusToString(RequirementStatus status) {
  switch (status) {
    case RequirementStatus.enviado:
      return 'enviado';
    case RequirementStatus.validado:
      return 'validado';
    case RequirementStatus.rechazado:
      return 'REJECTED';
    case RequirementStatus.pendiente:
      return 'pendiente';
  }
}

/// Tipo de requerimiento de clase progresiva.
enum RequirementType {
  /// Actividad general / tarea
  general,

  /// Especialidad (honor) requerida
  honor,

  /// Servicio comunitario
  service,
}

/// Parsea el string que llega desde la API al enum de tipo de requerimiento.
RequirementType requirementTypeFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'honor':
    case 'specialty':
      return RequirementType.honor;
    case 'service':
    case 'servicio':
      return RequirementType.service;
    default:
      return RequirementType.general;
  }
}

/// Un requerimiento dentro de un modulo de clase progresiva.
///
/// Cada requerimiento tiene un nombre, descripcion, tipo, peso en puntos,
/// limite de archivos de evidencia, y un flujo de estado propio.
class ClassRequirement extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int moduleId;
  final RequirementType type;

  /// Valor en puntos que otorga este requerimiento al validarse.
  final int pointValue;

  /// Limite maximo de archivos de evidencia.
  final int maxFiles;

  final RequirementStatus status;

  final List<RequirementEvidence> files;

  // Trazabilidad
  final String? submittedByName;
  final DateTime? submittedAt;
  final String? validatedByName;
  final DateTime? validatedAt;

  /// Puntos efectivamente ganados en este requerimiento (0 hasta validacion).
  final int earnedPoints;

  /// ID del honor vinculado (solo cuando type == RequirementType.honor).
  final int? linkedHonorId;

  /// Nombre del honor vinculado.
  final String? linkedHonorName;

  /// Si el honor vinculado ya fue completado por el usuario.
  final bool? linkedHonorCompleted;

  const ClassRequirement({
    required this.id,
    required this.name,
    this.description,
    required this.moduleId,
    this.type = RequirementType.general,
    this.pointValue = 0,
    this.maxFiles = 10,
    required this.status,
    this.files = const [],
    this.submittedByName,
    this.submittedAt,
    this.validatedByName,
    this.validatedAt,
    this.earnedPoints = 0,
    this.linkedHonorId,
    this.linkedHonorName,
    this.linkedHonorCompleted,
  });

  // Computed helpers

  /// Slots de archivos restantes.
  int get remainingSlots => (maxFiles - files.length).clamp(0, maxFiles);

  /// El miembro puede subir o eliminar archivos cuando esta pendiente o rechazado.
  bool get canUpload =>
      status == RequirementStatus.pendiente ||
      status == RequirementStatus.rechazado;

  /// El miembro puede enviar a validacion cuando tiene archivos y esta pendiente o rechazado.
  bool get canSubmit =>
      (status == RequirementStatus.pendiente ||
          status == RequirementStatus.rechazado) &&
      files.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        moduleId,
        type,
        pointValue,
        maxFiles,
        status,
        files,
        submittedByName,
        submittedAt,
        validatedByName,
        validatedAt,
        earnedPoints,
        linkedHonorId,
        linkedHonorName,
        linkedHonorCompleted,
      ];
}
