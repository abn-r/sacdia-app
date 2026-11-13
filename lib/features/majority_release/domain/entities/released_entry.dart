import 'package:equatable/equatable.dart';

/// Entrada mínima de una persona liberada en el historial del ex tutor
/// (`GET /guardianships/me/history`). Solo nombre y fecha: ni salud, ni club,
/// ni progreso, ni contacto, ni acciones sobre sus datos.
class ReleasedEntry extends Equatable {
  final String guardianshipId;
  final String dependentUserId;

  /// Nulo si la persona ya no existe como tal (anonimizada): la app muestra
  /// «Persona liberada».
  final String? displayName;
  final String? relationshipTypeName;
  final DateTime? releasedAt;

  /// Aún puede pedirse un código de acceso (sin cuenta y sin completar).
  final bool canIssueClaim;

  const ReleasedEntry({
    required this.guardianshipId,
    required this.dependentUserId,
    this.displayName,
    this.relationshipTypeName,
    this.releasedAt,
    this.canIssueClaim = false,
  });

  @override
  List<Object?> get props => [
        guardianshipId,
        dependentUserId,
        displayName,
        relationshipTypeName,
        releasedAt,
        canIssueClaim,
      ];
}
