import 'package:equatable/equatable.dart';

/// Entidad de camporee del dominio
class Camporee extends Equatable {
  final int camporeeId;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String place;
  final double? lat;
  final double? longitude;
  final double? registrationCost;
  final bool includesAdventurers;
  final bool includesPathfinders;
  final bool includesMasterGuides;
  final bool active;
  final int? localFieldId;
  final String? localFieldName;

  const Camporee({
    required this.camporeeId,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.place,
    this.lat,
    this.longitude,
    this.registrationCost,
    required this.includesAdventurers,
    required this.includesPathfinders,
    required this.includesMasterGuides,
    required this.active,
    this.localFieldId,
    this.localFieldName,
  });

  bool get hasLocation => lat != null && longitude != null;

  @override
  List<Object?> get props => [
        camporeeId,
        name,
        description,
        startDate,
        endDate,
        place,
        lat,
        longitude,
        registrationCost,
        includesAdventurers,
        includesPathfinders,
        includesMasterGuides,
        active,
        localFieldId,
        localFieldName,
      ];
}
