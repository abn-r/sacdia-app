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

  /// ID del campo local del club, usado para cargar categorías de puntuación.
  final int? localFieldId;

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

  /// Lista tal como la envía el backend (`scoring_members`): capitán,
  /// secretario y miembros, sin consejeros. Null = servidor anterior.
  final List<UnitMember>? serverScoringMembers;

  const Unit({
    required this.id,
    required this.name,
    required this.type,
    required this.memberCount,
    this.leaderName,
    this.clubTypeId,
    this.clubSectionId,
    this.localFieldId,
    this.captainId,
    this.secretaryId,
    this.advisorId,
    this.substituteAdvisorId,
    this.members = const [],
    this.serverScoringMembers,
  });

  /// ¿El servidor envió `scoring_members`?
  bool get hasServerScoringMembers => serverScoringMembers != null;

  /// Personas que reciben puntos: capitán, secretario y miembros; nunca los
  /// consejeros. Usa la lista del servidor y, si falta (servidor anterior),
  /// la deriva de [members] (capitán y secretario solo si ya están ahí).
  List<UnitMember> get scoringMembers {
    final fromServer = serverScoringMembers;
    if (fromServer != null) return fromServer;

    final excluded = <String>{
      if (advisorId != null && advisorId!.isNotEmpty) advisorId!,
      if (substituteAdvisorId != null && substituteAdvisorId!.isNotEmpty)
        substituteAdvisorId!,
    };
    final seen = <String>{};
    UnitMember? captain;
    UnitMember? secretary;
    final rest = <UnitMember>[];
    for (final m in members) {
      if (m.id.isEmpty || excluded.contains(m.id) || !seen.add(m.id)) continue;
      if (m.id == captainId) {
        captain = m.withRole(UnitMemberRole.captain);
      } else if (m.id == secretaryId) {
        secretary = m.withRole(UnitMemberRole.secretary);
      } else {
        rest.add(m.withRole(UnitMemberRole.member));
      }
    }
    return [
      if (captain != null) captain,
      if (secretary != null) secretary,
      ...rest,
    ];
  }

  /// ¿[userId] dirige esta unidad? Capitán, secretario, consejero o consejero
  /// suplente. Un id nulo o vacío nunca dirige (falla cerrado).
  bool isLedBy(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return captainId == userId ||
        secretaryId == userId ||
        advisorId == userId ||
        substituteAdvisorId == userId;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Unit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
