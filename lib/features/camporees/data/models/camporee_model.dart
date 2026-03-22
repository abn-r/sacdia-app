import 'package:equatable/equatable.dart';
import '../../domain/entities/camporee.dart';

/// Modelo de camporee para la capa de datos
class CamporeeModel extends Equatable {
  final int camporeeId;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String place;
  final double? registrationCost;
  final bool includesAdventurers;
  final bool includesPathfinders;
  final bool includesMasterGuides;
  final bool active;
  final int? localFieldId;
  final String? localFieldName;

  const CamporeeModel({
    required this.camporeeId,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.place,
    this.registrationCost,
    required this.includesAdventurers,
    required this.includesPathfinders,
    required this.includesMasterGuides,
    required this.active,
    this.localFieldId,
    this.localFieldName,
  });

  /// Crea una instancia desde JSON (snake_case → camelCase)
  factory CamporeeModel.fromJson(Map<String, dynamic> json) {
    final localFields = json['local_fields'] as Map<String, dynamic>?;

    return CamporeeModel(
      camporeeId:
          (json['local_camporee_id'] ?? json['camporee_id'] ?? json['id'])
              as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      place: (json['local_camporee_place'] ?? json['place'] ?? '') as String,
      registrationCost: json['registration_cost'] != null
          ? (json['registration_cost'] as num).toDouble()
          : null,
      includesAdventurers:
          json['includes_adventurers'] as bool? ?? false,
      includesPathfinders:
          json['includes_pathfinders'] as bool? ?? false,
      includesMasterGuides:
          json['includes_master_guides'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      localFieldId: localFields != null
          ? localFields['local_field_id'] as int?
          : json['local_field_id'] as int?,
      localFieldName:
          localFields != null ? localFields['name'] as String? : null,
    );
  }

  /// Convierte el modelo a entidad de dominio
  Camporee toEntity() {
    return Camporee(
      camporeeId: camporeeId,
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      place: place,
      registrationCost: registrationCost,
      includesAdventurers: includesAdventurers,
      includesPathfinders: includesPathfinders,
      includesMasterGuides: includesMasterGuides,
      active: active,
      localFieldId: localFieldId,
      localFieldName: localFieldName,
    );
  }

  @override
  List<Object?> get props => [
        camporeeId,
        name,
        description,
        startDate,
        endDate,
        place,
        registrationCost,
        includesAdventurers,
        includesPathfinders,
        includesMasterGuides,
        active,
        localFieldId,
        localFieldName,
      ];
}
