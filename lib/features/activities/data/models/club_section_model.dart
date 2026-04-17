import 'package:equatable/equatable.dart';

/// Modelo ligero de sección de club, usado en el picker de actividades conjuntas.
///
/// Mapeado desde GET /api/v1/clubs/:clubId/sections
class ClubSectionModel extends Equatable {
  final int clubSectionId;
  final int clubTypeId;
  final String? clubTypeName;
  final bool active;

  const ClubSectionModel({
    required this.clubSectionId,
    required this.clubTypeId,
    this.clubTypeName,
    required this.active,
  });

  factory ClubSectionModel.fromJson(Map<String, dynamic> json) {
    final clubTypesNested = json['club_types'] as Map<String, dynamic>?;
    return ClubSectionModel(
      clubSectionId: json['club_section_id'] as int,
      clubTypeId: (json['club_type_id'] as int?) ?? 0,
      clubTypeName: clubTypesNested?['name'] as String?,
      active: (json['active'] as bool?) ?? false,
    );
  }

  @override
  List<Object?> get props => [clubSectionId, clubTypeId, clubTypeName, active];
}
