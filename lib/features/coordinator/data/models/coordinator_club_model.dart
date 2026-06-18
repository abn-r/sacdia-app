import '../../domain/entities/coordinator_club.dart';
import '../../domain/entities/coordinator_scope.dart';

/// Modelo de datos para la lista de clubs vista por el coordinador.
///
/// Hoy se puede construir desde el scope efectivo de coordinación:
///   GET /api/v1/coordination/me/scope
class CoordinatorClubModel extends CoordinatorClub {
  const CoordinatorClubModel({
    required super.id,
    required super.name,
    required super.localFieldId,
    super.localFieldName,
    super.districtName,
    super.sections,
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
      localFieldName: json['local_field_name'] as String?,
      districtName: json['district_name'] as String?,
    );
  }

  static List<CoordinatorClubModel> fromSections(
    List<CoordinatorSectionScope> sections,
  ) {
    final grouped = <int, List<CoordinatorSectionScope>>{};

    for (final section in sections) {
      final clubId = section.clubId;
      if (clubId == null) continue;
      grouped.putIfAbsent(clubId, () => []).add(section);
    }

    final clubs = grouped.entries.map((entry) {
      final first = entry.value.first;
      return CoordinatorClubModel(
        id: entry.key,
        name: first.clubName ?? 'Club #${entry.key}',
        localFieldId: first.localFieldId ?? 0,
        localFieldName: first.localFieldName,
        districtName: first.districtName,
        sections: entry.value,
      );
    }).toList();

    clubs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return clubs;
  }

  Map<String, dynamic> toJson() => {
        'club_id': id,
        'name': name,
        'local_field_id': localFieldId,
        'local_field_name': localFieldName,
        'district_name': districtName,
      };
}
