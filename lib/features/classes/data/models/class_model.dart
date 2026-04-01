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

  /// Estado de investidura proveniente del enrollment.
  /// Valores posibles: null (no inscrito), 'PENDIENTE', 'INVESTIDO', etc.
  final String? investitureStatus;

  /// Progreso general de 0 a 100, proveniente del enrollment.
  final int? overallProgress;

  const ClassModel({
    required this.id,
    required this.name,
    this.description,
    required this.clubTypeId,
    this.imageUrl,
    this.investitureStatus,
    this.overallProgress,
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
      investitureStatus: safeStringOrNull(json['investiture_status']),
      overallProgress: safeIntOrNull(json['overall_progress']),
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
      'investiture_status': investitureStatus,
      'overall_progress': overallProgress,
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
      investitureStatus: investitureStatus,
      overallProgress: overallProgress,
    );
  }

  /// Crea una copia con campos actualizados
  ClassModel copyWith({
    int? id,
    String? name,
    String? description,
    int? clubTypeId,
    String? imageUrl,
    String? investitureStatus,
    int? overallProgress,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      clubTypeId: clubTypeId ?? this.clubTypeId,
      imageUrl: imageUrl ?? this.imageUrl,
      investitureStatus: investitureStatus ?? this.investitureStatus,
      overallProgress: overallProgress ?? this.overallProgress,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        clubTypeId,
        imageUrl,
        investitureStatus,
        overallProgress,
      ];
}
