import 'package:equatable/equatable.dart';

/// Modelo de instancia de club (tipo específico de club)
class ClubInstanceModel extends Equatable {
  final int id;
  final int clubTypeId;
  final int clubId;

  /// Slug canónico del tipo de club: adventurers | pathfinders | master_guild
  final String clubTypeSlug;

  /// Nombre legible (puede ser null si el API no lo devuelve)
  final String? clubTypeName;

  const ClubInstanceModel({
    required this.id,
    required this.clubTypeId,
    required this.clubId,
    required this.clubTypeSlug,
    this.clubTypeName,
  });

  /// Parsea un item individual desde el bucket de instancias.
  /// [slug] es la clave del bucket normalizada (master_guilds → master_guild).
  /// [idKey] es el campo de ID específico del bucket (ej: 'club_adv_id').
  factory ClubInstanceModel.fromJsonWithSlug(
      Map<String, dynamic> json, String slug, String idKey) {
    // Cada bucket tiene su propio campo de ID en la respuesta de la API:
    //   adventurers  → club_adv_id
    //   pathfinders  → club_pathf_id
    //   master_guilds → club_mg_id
    final rawId = json[idKey] ?? json['club_instance_id'] ?? json['id'];
    final rawClubTypeId = json['club_type_id'];
    final rawClubId = json['club_id'];

    return ClubInstanceModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      clubTypeId: rawClubTypeId is int
          ? rawClubTypeId
          : (int.tryParse(rawClubTypeId?.toString() ?? '') ?? 0),
      clubId: rawClubId is int
          ? rawClubId
          : (int.tryParse(rawClubId?.toString() ?? '') ?? 0),
      clubTypeSlug: slug,
      clubTypeName: json['club_type_name'] as String?,
    );
  }

  /// Legacy factory — kept for compatibility; slug defaults to empty string.
  factory ClubInstanceModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['club_instance_id'] ?? json['id'];
    final rawClubTypeId = json['club_type_id'];
    final rawClubId = json['club_id'];

    return ClubInstanceModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      clubTypeId: rawClubTypeId is int
          ? rawClubTypeId
          : (int.tryParse(rawClubTypeId?.toString() ?? '') ?? 0),
      clubId: rawClubId is int
          ? rawClubId
          : (int.tryParse(rawClubId?.toString() ?? '') ?? 0),
      clubTypeSlug: json['club_type_slug'] as String? ?? '',
      clubTypeName: json['club_type_name'] as String?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'club_instance_id': id,
      'club_type_id': clubTypeId,
      'club_id': clubId,
      'club_type_slug': clubTypeSlug,
      if (clubTypeName != null) 'club_type_name': clubTypeName,
    };
  }

  /// Nombre para mostrar: usa clubTypeName si viene del API,
  /// o traduce el slug al español como fallback.
  String get displayName {
    if (clubTypeName != null && clubTypeName!.isNotEmpty) return clubTypeName!;
    switch (clubTypeSlug) {
      case 'adventurers':
        return 'Aventureros';
      case 'pathfinders':
        return 'Conquistadores';
      case 'master_guild':
      case 'master_guilds':
        return 'Guías Mayores';
      default:
        return clubTypeSlug;
    }
  }

  /// Crea una copia con campos actualizados
  ClubInstanceModel copyWith({
    int? id,
    int? clubTypeId,
    int? clubId,
    String? clubTypeSlug,
    String? clubTypeName,
  }) {
    return ClubInstanceModel(
      id: id ?? this.id,
      clubTypeId: clubTypeId ?? this.clubTypeId,
      clubId: clubId ?? this.clubId,
      clubTypeSlug: clubTypeSlug ?? this.clubTypeSlug,
      clubTypeName: clubTypeName ?? this.clubTypeName,
    );
  }

  @override
  List<Object?> get props => [id, clubTypeId, clubId, clubTypeSlug];
}
