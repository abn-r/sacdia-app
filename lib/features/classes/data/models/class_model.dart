import 'package:equatable/equatable.dart';
import '../../domain/entities/progressive_class.dart';
import '../../../../core/utils/json_helpers.dart';

/// Modelo de clase progresiva para la capa de datos
class ClassModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int clubTypeId;
  final String? imageUrl;

  /// Owner anual del progreso cuando el modelo viene de `GET /users/:id/classes`.
  final int? enrollmentId;

  /// Estado de investidura proveniente del enrollment.
  /// Valores posibles: null (no inscrito), 'PENDIENTE', 'INVESTIDO', etc.
  final String? investitureStatus;

  /// Progreso general de 0 a 100, proveniente del enrollment.
  final int? overallProgress;

  /// Código de asset local para el roadmap (e.g. "AV-01", "CQ-03").
  /// Mapeado desde el campo snake_case `asset_code` del backend.
  final String? assetCode;

  final int? availableFromYearId;
  final int? availableUntilYearId;
  final int minDurationYears;
  final int maxDurationYears;

  const ClassModel({
    required this.id,
    required this.name,
    this.description,
    required this.clubTypeId,
    this.imageUrl,
    this.enrollmentId,
    this.investitureStatus,
    this.overallProgress,
    this.assetCode,
    this.availableFromYearId,
    this.availableUntilYearId,
    this.minDurationYears = 1,
    this.maxDurationYears = 1,
  });

  /// Crea una instancia desde JSON.
  ///
  /// Acepta tanto el JSON de clase plano (catálogo) como el JSON ya mezclado
  /// con campos de enrollment (investiture_status, overall_progress).
  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      // Backend uses 'class_id' as PK; 'id' is fallback for catalog endpoint
      id: safeInt(json['class_id'] ?? json['id']),
      name: safeString(json['name']),
      description: safeStringOrNull(json['description']),
      // Enrollment response nests club type; catalog has flat club_type_id
      clubTypeId: safeInt(json['club_type_id']),
      imageUrl: safeStringOrNull(json['image_url']),
      enrollmentId:
          safeIntOrNull(json['enrollment_id'] ?? json['enrollmentId']),
      investitureStatus: safeStringOrNull(json['investiture_status']),
      overallProgress: safeIntOrNull(json['overall_progress']),
      assetCode: safeStringOrNull(json['asset_code']),
      availableFromYearId: safeIntOrNull(
          json['available_from_year_id'] ?? json['availableFromYearId']),
      availableUntilYearId: safeIntOrNull(
          json['available_until_year_id'] ?? json['availableUntilYearId']),
      minDurationYears:
          safeInt(json['min_duration_years'] ?? json['minDurationYears'], 1),
      maxDurationYears:
          safeInt(json['max_duration_years'] ?? json['maxDurationYears'], 1),
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'club_type_id': clubTypeId,
      'image_url': imageUrl,
      'enrollment_id': enrollmentId,
      'investiture_status': investitureStatus,
      'overall_progress': overallProgress,
      'asset_code': assetCode,
      'available_from_year_id': availableFromYearId,
      'available_until_year_id': availableUntilYearId,
      'min_duration_years': minDurationYears,
      'max_duration_years': maxDurationYears,
    };
  }

  /// Convierte el modelo a entidad de dominio
  ProgressiveClass toEntity() {
    return ProgressiveClass(
      id: id,
      name: name,
      description: description,
      clubTypeId: clubTypeId,
      imageUrl: imageUrl,
      enrollmentId: enrollmentId,
      investitureStatus: investitureStatus,
      overallProgress: overallProgress,
      assetCode: assetCode,
      availableFromYearId: availableFromYearId,
      availableUntilYearId: availableUntilYearId,
      minDurationYears: minDurationYears,
      maxDurationYears: maxDurationYears,
    );
  }

  /// Crea una copia con campos actualizados
  ClassModel copyWith({
    int? id,
    String? name,
    String? description,
    int? clubTypeId,
    String? imageUrl,
    int? enrollmentId,
    String? investitureStatus,
    int? overallProgress,
    String? assetCode,
    int? availableFromYearId,
    int? availableUntilYearId,
    int? minDurationYears,
    int? maxDurationYears,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      clubTypeId: clubTypeId ?? this.clubTypeId,
      imageUrl: imageUrl ?? this.imageUrl,
      enrollmentId: enrollmentId ?? this.enrollmentId,
      investitureStatus: investitureStatus ?? this.investitureStatus,
      overallProgress: overallProgress ?? this.overallProgress,
      assetCode: assetCode ?? this.assetCode,
      availableFromYearId: availableFromYearId ?? this.availableFromYearId,
      availableUntilYearId: availableUntilYearId ?? this.availableUntilYearId,
      minDurationYears: minDurationYears ?? this.minDurationYears,
      maxDurationYears: maxDurationYears ?? this.maxDurationYears,
    );
  }

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
        availableFromYearId,
        availableUntilYearId,
        minDurationYears,
        maxDurationYears,
      ];
}
