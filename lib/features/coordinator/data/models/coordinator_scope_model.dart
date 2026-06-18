import '../../domain/entities/coordinator_scope.dart';

class CoordinatorScopeModel extends CoordinatorScope {
  const CoordinatorScopeModel({
    required super.isCoordinator,
    super.clubSectionIds,
    super.sections,
  });

  factory CoordinatorScopeModel.fromJson(Map<String, dynamic> json) {
    final rawSectionIds = json['club_section_ids'];
    final rawSections = json['sections'];

    return CoordinatorScopeModel(
      isCoordinator: json['is_coordinator'] == true,
      clubSectionIds: rawSectionIds is List
          ? rawSectionIds.map(_toInt).where((id) => id > 0).toList()
          : const [],
      sections: rawSections is List
          ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(CoordinatorSectionScopeModel.fromJson)
              .toList()
          : const [],
    );
  }
}

class CoordinatorSectionScopeModel extends CoordinatorSectionScope {
  const CoordinatorSectionScopeModel({
    required super.clubSectionId,
    super.name,
    required super.clubTypeId,
    super.clubTypeName,
    super.clubId,
    super.clubName,
    super.districtId,
    super.districtName,
    super.localFieldId,
    super.localFieldName,
  });

  factory CoordinatorSectionScopeModel.fromJson(Map<String, dynamic> json) {
    return CoordinatorSectionScopeModel(
      clubSectionId: _toInt(json['club_section_id']),
      name: _toNullableString(json['name']),
      clubTypeId: _toInt(json['club_type_id']),
      clubTypeName: _toNullableString(json['club_type_name']),
      clubId: _toNullableInt(json['club_id']),
      clubName: _toNullableString(json['club_name']),
      districtId: _toNullableInt(json['district_id']),
      districtName: _toNullableString(json['district_name']),
      localFieldId: _toNullableInt(json['local_field_id']),
      localFieldName: _toNullableString(json['local_field_name']),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  final parsed = _toInt(value);
  return parsed == 0 ? null : parsed;
}

String? _toNullableString(dynamic value) {
  final parsed = value?.toString().trim();
  return parsed == null || parsed.isEmpty ? null : parsed;
}
