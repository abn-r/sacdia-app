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

/// Entidad de dominio para una sección de club
/// (Aventureros, Conquistadores o Guías Mayores).
class ClubSection extends Equatable {
  /// ID numérico de la sección (club_section_id).
  final int id;

  /// ID del club contenedor (UUID).
  final String mainClubId;

  /// club_type_id del tipo de sección.
  final int clubTypeId;

  /// Nombre legible del tipo (ej: 'Conquistadores').
  final String clubTypeName;

  /// Nombre propio de la sección.
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

  /// ¿Sección activa?
  final bool active;

  const ClubSection({
    required this.id,
    required this.mainClubId,
    required this.clubTypeId,
    required this.clubTypeName,
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
        id, mainClubId, clubTypeId, clubTypeName,
        name, phone, email, website, logoUrl, address, lat, long, active,
      ];
}
