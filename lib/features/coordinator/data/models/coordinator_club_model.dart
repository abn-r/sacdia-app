import '../../domain/entities/coordinator_club.dart';

/// Modelo de datos para la lista de clubs vista por el coordinador.
///
/// Mapea la respuesta paginada de:
///   GET /api/v1/clubs?localFieldId=...
///
/// El backend envuelve en { data: [...] } o devuelve la lista directamente.
class CoordinatorClubModel extends CoordinatorClub {
  const CoordinatorClubModel({
    required super.id,
    required super.name,
    required super.localFieldId,
  });

  factory CoordinatorClubModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['club_id'] ?? json['id'];
    final rawFieldId = json['local_field_id'];

    return CoordinatorClubModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
      localFieldId: rawFieldId is int
          ? rawFieldId
          : (int.tryParse(rawFieldId?.toString() ?? '') ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'club_id': id,
        'name': name,
        'local_field_id': localFieldId,
      };
}
