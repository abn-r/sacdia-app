import 'package:equatable/equatable.dart';

/// Entidad de dominio para la información del club contenedor.
class ClubInfo extends Equatable {
  /// ID único del club (UUID).
  final String id;

  /// Nombre del club.
  final String name;

  /// ¿Club activo?
  final bool active;

  const ClubInfo({
    required this.id,
    required this.name,
    required this.active,
  });

  @override
  List<Object?> get props => [id, name, active];
}

/// Entidad de dominio para una instancia de club
/// (Aventureros, Conquistadores o Guías Mayores).
class ClubInstance extends Equatable {
  /// ID numérico de la instancia.
  final int id;

  /// ID del club contenedor (UUID).
  final String mainClubId;

  /// Slug del tipo de instancia: 'adventurers' | 'pathfinders' | 'master_guild'
  final String instanceType;

  /// Nombre legible del tipo (ej: 'Conquistadores').
  final String instanceTypeName;

  /// Nombre propio de la instancia.
  final String? name;

  /// Teléfono de contacto.
  final String? phone;

  /// Email de contacto.
  final String? email;

  /// Sitio web.
  final String? website;

  /// URL del logo/imagen.
  final String? logoUrl;

  /// Dirección física.
  final String? address;

  /// Latitud de la ubicación.
  final double? lat;

  /// Longitud de la ubicación.
  final double? long;

  /// ¿Instancia activa?
  final bool active;

  const ClubInstance({
    required this.id,
    required this.mainClubId,
    required this.instanceType,
    required this.instanceTypeName,
    this.name,
    this.phone,
    this.email,
    this.website,
    this.logoUrl,
    this.address,
    this.lat,
    this.long,
    required this.active,
  });

  @override
  List<Object?> get props => [
        id,
        mainClubId,
        instanceType,
        instanceTypeName,
        name,
        phone,
        email,
        website,
        logoUrl,
        address,
        lat,
        long,
        active,
      ];
}
