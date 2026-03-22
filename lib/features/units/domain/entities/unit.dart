import 'unit_member.dart';

/// Representa una unidad dentro de un club SACDIA
/// (Conquistadores, Aventureros o Guías Mayores).
class Unit {
  final int id;
  final String name;

  /// Tipo de club (ej. "Conquistadores", "Aventureros", "Guías Mayores").
  final String type;

  /// Cantidad de miembros activos en la unidad.
  final int memberCount;

  /// Nombre completo del líder/capitán (null si no tiene).
  final String? leaderName;

  // ── Campos extendidos del backend ─────────────────────────────────────────

  /// ID del tipo de club en la BD (1=Aventureros, 2=Conquistadores, 3=GM).
  final int? clubTypeId;

  /// ID de la sección del club a la que pertenece.
  final int? clubSectionId;

  /// UUID del capitán.
  final String? captainId;

  /// UUID del secretario.
  final String? secretaryId;

  /// UUID del consejero/asesor.
  final String? advisorId;

  /// UUID del consejero suplente.
  final String? substituteAdvisorId;

  /// Lista de miembros activos (incluida en el detalle de la unidad).
  final List<UnitMember> members;

  const Unit({
    required this.id,
    required this.name,
    required this.type,
    required this.memberCount,
    this.leaderName,
    this.clubTypeId,
    this.clubSectionId,
    this.captainId,
    this.secretaryId,
    this.advisorId,
    this.substituteAdvisorId,
    this.members = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Unit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
