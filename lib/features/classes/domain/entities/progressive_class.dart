import 'package:equatable/equatable.dart';

import 'class_prerequisite.dart';

/// Entidad de clase progresiva del dominio
class ProgressiveClass extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int clubTypeId;
  final String? imageUrl;
  final int? enrollmentId;

  /// Estado de investidura proveniente del enrollment.
  /// Valores posibles: null (no inscrito), 'PENDIENTE', 'INVESTIDO', etc.
  final String? investitureStatus;

  /// Progreso general de 0 a 100, proveniente del enrollment.
  final int? overallProgress;

  /// Código de asset local para el roadmap (e.g. "AV-01", "CQ-03").
  /// Cuando está presente, se usa para resolver directamente el asset local
  /// en lugar de inferirlo por posición ordinal.
  /// Null hasta que el backend esté desplegado con el campo poblado.
  final String? assetCode;

  /// Edad mínima para iniciar la clase (`classes.minimum_age`).
  /// Null si el catálogo aún no envía el campo.
  final int? minimumAge;

  /// Fecha de inscripción del enrollment (si viene en el listado).
  final DateTime? enrollmentDate;

  /// Fecha de envío a validación (si aplica).
  final DateTime? submittedAt;

  /// Fecha de última validación registrada en el enrollment.
  final DateTime? validatedAt;

  /// Rango del año eclesiástico del enrollment (ej. "2025–2026").
  final String? ecclesiasticalYearLabel;

  /// Año eclesiástico desde el que se puede iniciar la clase.
  final int? availableFromYearId;

  /// Año eclesiástico hasta el que se puede iniciar la clase.
  ///
  /// Null significa que no tiene expiración programada.
  final int? availableUntilYearId;

  /// Duración mínima requerida, en años eclesiásticos.
  final int minDurationYears;

  /// Duración máxima permitida, en años eclesiásticos.
  final int maxDurationYears;

  /// Clases previas que el usuario debe tener investidas para poder
  /// inscribirse en esta clase (`class_prerequisites` activos).
  final List<ClassPrerequisite> prerequisites;

  const ProgressiveClass({
    required this.id,
    required this.name,
    this.description,
    required this.clubTypeId,
    this.imageUrl,
    this.enrollmentId,
    this.investitureStatus,
    this.overallProgress,
    this.assetCode,
    this.minimumAge,
    this.enrollmentDate,
    this.submittedAt,
    this.validatedAt,
    this.ecclesiasticalYearLabel,
    this.availableFromYearId,
    this.availableUntilYearId,
    this.minDurationYears = 1,
    this.maxDurationYears = 1,
    this.prerequisites = const [],
  });

  bool get isExpired => investitureStatus?.trim().toUpperCase() == 'EXPIRED';

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        clubTypeId,
        imageUrl,
        enrollmentId,
        investitureStatus,
        overallProgress,
        assetCode,
        minimumAge,
        enrollmentDate,
        submittedAt,
        validatedAt,
        ecclesiasticalYearLabel,
        availableFromYearId,
        availableUntilYearId,
        minDurationYears,
        maxDurationYears,
        prerequisites,
      ];
}
