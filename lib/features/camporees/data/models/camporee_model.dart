import 'package:equatable/equatable.dart';
import '../../domain/entities/camporee.dart';
import '../../../../core/utils/json_helpers.dart';

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
      camporeeId: safeInt(
          json['local_camporee_id'] ?? json['camporee_id'] ?? json['id']),
      name: safeString(json['name']),
      description: safeStringOrNull(json['description']),
      startDate: DateTime.parse(safeString(json['start_date'])),
      endDate: DateTime.parse(safeString(json['end_date'])),
      place: safeString(json['local_camporee_place'] ?? json['place']),
      registrationCost: json['registration_cost'] != null
          ? (json['registration_cost'] as num).toDouble()
          : null,
      includesAdventurers: safeBool(json['includes_adventurers']),
      includesPathfinders: safeBool(json['includes_pathfinders']),
      includesMasterGuides: safeBool(json['includes_master_guides']),
      active: safeBool(json['active'], true),
      localFieldId: localFields != null
          ? safeIntOrNull(localFields['local_field_id'])
          : safeIntOrNull(json['local_field_id']),
      localFieldName:
          localFields != null ? safeStringOrNull(localFields['name']) : null,
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
