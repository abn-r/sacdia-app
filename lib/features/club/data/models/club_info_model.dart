import '../../domain/entities/club_info.dart';

/// Mapa de club_type slugs a nombres legibles en español.
/// Fallback para cuando club_type.name no viene del API.
const _clubTypeDisplayNames = {
  'adventurers': 'Aventureros',
  'pathfinders': 'Conquistadores',
  'master_guild': 'Guías Mayores',
};

// ─────────────────────────────────────────────────────────────────────────────
// ClubInfoModel
// ─────────────────────────────────────────────────────────────────────────────

/// Modelo de datos para el club contenedor.
///
/// Mapea la respuesta de:
///   GET /api/v1/clubs/:clubId
class ClubInfoModel extends ClubInfo {
  const ClubInfoModel({
    required super.id,
    required super.name,
    required super.active,
  });

  factory ClubInfoModel.fromJson(Map<String, dynamic> json) {
    return ClubInfoModel(
      id: (json['id'] ?? json['club_id'] ?? '').toString(),
      name: (json['name'] ?? json['club_name'] ?? '').toString(),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'active': active,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// ClubSectionModel
// ─────────────────────────────────────────────────────────────────────────────

/// Modelo de datos para una sección de club.
///
/// Mapea la respuesta de:
///   GET /api/v1/clubs/:clubId/sections/:sectionId
class ClubSectionModel extends ClubSection {
  const ClubSectionModel({
    required super.id,
    required super.mainClubId,
    required super.clubTypeId,
    required super.clubTypeName,
    super.name,
    super.phone,
    super.email,
    super.website,
    super.logoUrl,
    super.address,
    super.lat,
    super.long,
    required super.active,
  });

  factory ClubSectionModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['club_section_id'] ?? json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    final mainClubId =
        (json['main_club_id'] ?? json['club_id'] ?? '').toString();

    // club_type_id is the discriminator
    final rawClubTypeId = json['club_type_id'];
    final clubTypeId = rawClubTypeId is int
        ? rawClubTypeId
        : (int.tryParse(rawClubTypeId?.toString() ?? '') ?? 0);

    // Determine display name from nested club_type or slug fallback
    final clubTypeNested = json['club_type'] as Map<String, dynamic>?;
    final clubTypeName = clubTypeNested?['name'] as String? ??
        _clubTypeDisplayNames[clubTypeNested?['slug']] ??
        '';

    final lat = _parseDouble(json['lat'] ?? json['latitude']);
    final long = _parseDouble(json['long'] ?? json['longitude'] ?? json['lng']);

    return ClubSectionModel(
      id: id,
      mainClubId: mainClubId,
      clubTypeId: clubTypeId,
      clubTypeName: clubTypeName,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      logoUrl: json['logo_url'] as String? ?? json['image'] as String?,
      address: json['address'] as String?,
      lat: lat,
      long: long,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'club_section_id': id,
      'main_club_id': mainClubId,
      'club_type_id': clubTypeId,
      'active': active,
    };
    if (name != null) map['name'] = name;
    if (phone != null) map['phone'] = phone;
    if (email != null) map['email'] = email;
    if (website != null) map['website'] = website;
    if (logoUrl != null) map['logo_url'] = logoUrl;
    if (address != null) map['address'] = address;
    if (lat != null) map['lat'] = lat;
    if (long != null) map['long'] = long;
    return map;
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
