import 'package:equatable/equatable.dart';

/// Modelo de sección de club (tipo específico de club)
class ClubSectionModel extends Equatable {
  final int id;
  final int clubTypeId;
  final int clubId;

  /// Slug canónico del tipo de club: adventurers | pathfinders | master_guild
  final String clubTypeSlug;

  /// Nombre legible (puede ser null si el API no lo devuelve)
  final String? clubTypeName;

  const ClubSectionModel({
    required this.id,
    required this.clubTypeId,
    required this.clubId,
    required this.clubTypeSlug,
    this.clubTypeName,
  });

  /// Parsea un item desde la respuesta de GET /clubs/:clubId/sections
  ///
  /// El backend devuelve el nombre del tipo de club anidado en
  /// `club_types.name`, no como campo plano `club_type_name`.
  /// También usa `main_club_id` en vez de `club_id`.
  factory ClubSectionModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['club_section_id'] ?? json['id'];
    final rawClubTypeId = json['club_type_id'];
    final rawClubId = json['main_club_id'] ?? json['club_id'];

    // El nombre viene anidado en club_types.name o como campo plano
    final clubTypes = json['club_types'] as Map<String, dynamic>?;
    final clubTypeName =
        json['club_type_name'] as String? ?? clubTypes?['name'] as String?;

    // Derivar slug del nombre si no viene explícito
    final explicitSlug = json['club_type_slug'] as String? ?? '';
    final slug = explicitSlug.isNotEmpty
        ? explicitSlug
        : _slugFromName(clubTypeName);

    return ClubSectionModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      clubTypeId: rawClubTypeId is int
          ? rawClubTypeId
          : (int.tryParse(rawClubTypeId?.toString() ?? '') ?? 0),
      clubId: rawClubId is int
          ? rawClubId
          : (int.tryParse(rawClubId?.toString() ?? '') ?? 0),
      clubTypeSlug: slug,
      clubTypeName: clubTypeName,
    );
  }

  /// Deriva el slug canónico a partir del nombre legible del tipo de club.
  static String _slugFromName(String? name) {
    if (name == null || name.isEmpty) return '';
    final lower = name.toLowerCase();
    if (lower.contains('aventurero') || lower.contains('adventurer')) {
      return 'adventurers';
    }
    if (lower.contains('conquistador') || lower.contains('pathfinder')) {
      return 'pathfinders';
    }
    if (lower.contains('guía') ||
        lower.contains('guia') ||
        lower.contains('master')) {
      return 'master_guild';
    }
    return '';
  }

  /// Convierte la sección a JSON
  Map<String, dynamic> toJson() {
    return {
      'club_section_id': id,
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
  ClubSectionModel copyWith({
    int? id,
    int? clubTypeId,
    int? clubId,
    String? clubTypeSlug,
    String? clubTypeName,
  }) {
    return ClubSectionModel(
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
