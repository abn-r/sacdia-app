import '../../domain/entities/club_info.dart';

/// Mapa de slugs de tipo de instancia a nombres legibles en español.
const _instanceTypeNames = {
  'adventurers': 'Aventureros',
  'pathfinders': 'Conquistadores',
  'master_guild': 'Guías Mayores',
};

/// Mapa de slugs a la clave que usa el backend en la URL del endpoint.
/// GET /api/v1/clubs/:clubId/instances/:type/:instanceId
const _instanceTypeSlugs = {
  'adventurers': 'adventurers',
  'pathfinders': 'pathfinders',
  'master_guild': 'master_guild',
  // Aliases por si el backend usa otros valores
  'conquistadores': 'pathfinders',
  'aventureros': 'adventurers',
  'guias_mayores': 'master_guild',
};

/// Normaliza un slug de tipo de instancia al formato canónico del backend.
String normalizeInstanceType(String raw) {
  final lower = raw.toLowerCase().replaceAll(' ', '_');
  return _instanceTypeSlugs[lower] ?? lower;
}

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
// ClubInstanceModel
// ─────────────────────────────────────────────────────────────────────────────

/// Modelo de datos para una instancia de club.
///
/// Mapea la respuesta de:
///   GET /api/v1/clubs/:clubId/instances/:type/:instanceId
class ClubInstanceModel extends ClubInstance {
  const ClubInstanceModel({
    required super.id,
    required super.mainClubId,
    required super.instanceType,
    required super.instanceTypeName,
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

  factory ClubInstanceModel.fromJson(
    Map<String, dynamic> json, {
    String? knownInstanceType,
  }) {
    // El backend puede devolver el ID como int o string
    final rawId = json['id'] ?? json['club_instance_id'] ?? json['instance_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    // ID del club contenedor
    final mainClubId =
        (json['main_club_id'] ?? json['club_id'] ?? '').toString();

    // Determinar el tipo de instancia
    final typeRaw = knownInstanceType ??
        json['club_type'] as String? ??
        json['instance_type'] as String? ??
        json['type'] as String? ??
        '';
    final instanceType = normalizeInstanceType(typeRaw);
    final instanceTypeName =
        _instanceTypeNames[instanceType] ?? typeRaw;

    // Coordenadas
    final lat = _parseDouble(json['lat'] ?? json['latitude']);
    final long = _parseDouble(json['long'] ?? json['longitude'] ?? json['lng']);

    return ClubInstanceModel(
      id: id,
      mainClubId: mainClubId,
      instanceType: instanceType,
      instanceTypeName: instanceTypeName,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      logoUrl: json['logo_url'] ?? json['image'] as String?,
      address: json['address'] as String?,
      lat: lat,
      long: long,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'main_club_id': mainClubId,
      'instance_type': instanceType,
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
