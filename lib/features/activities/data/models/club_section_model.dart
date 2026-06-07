import '../../domain/entities/activity_club_section.dart';

/// Modelo ligero de sección de club, usado en el picker de actividades conjuntas.
///
/// Mapeado desde GET /api/v1/clubs/:clubId/sections
class ClubSectionModel extends ActivityClubSection {
  const ClubSectionModel({
    required super.clubSectionId,
    required super.clubTypeId,
    super.clubTypeName,
    required super.active,
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
}
