import '../../domain/entities/unit.dart';
import '../../domain/entities/unit_member.dart';
import 'unit_member_model.dart';

/// Modelo de datos para una unidad del club.
///
/// El backend retorna la estructura completa con relaciones incluidas.
/// Respuesta esperada de GET /api/v1/clubs/:clubId/units:
/// ```json
/// {
///   "unit_id": 1,
///   "name": "Unidad Alpha",
///   "active": true,
///   "club_type_id": 2,
///   "club_section_id": 5,
///   "captain_id": "uuid",
///   "secretary_id": "uuid",
///   "advisor_id": "uuid",
///   "substitute_advisor_id": null,
///   "club_types": { "club_type_id": 2, "name": "Conquistadores" },
///   "club_sections": { "club_section_id": 5, "main_club_id": 1 },
///   "users_units_captain_idTousers": {
///     "user_id": "uuid",
///     "name": "Juan",
///     "paternal_last_name": "Pérez",
///     "user_image": "https://..."
///   },
///   "unit_members": [
///     {
///       "unit_member_id": 1,
///       "user_id": "uuid",
///       "active": true,
///       "users": { ... }
///     }
///   ]
/// }
/// ```
class UnitModel extends Unit {
  const UnitModel({
    required super.id,
    required super.name,
    required super.type,
    required super.memberCount,
    super.leaderName,
    super.clubTypeId,
    super.clubSectionId,
    super.captainId,
    super.secretaryId,
    super.advisorId,
    super.substituteAdvisorId,
    super.members,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    // Tipo de club
    final clubTypeData = json['club_types'] as Map<String, dynamic>?;
    final typeName = clubTypeData?['name']?.toString() ?? 'Sin tipo';

    // Capitán
    final captainData =
        json['users_units_captain_idTousers'] as Map<String, dynamic>?;
    final captainName = captainData != null
        ? [
            captainData['name']?.toString() ?? '',
            captainData['paternal_last_name']?.toString() ?? '',
          ].where((s) => s.isNotEmpty).join(' ')
        : null;

    // Sección
    final sectionData = json['club_sections'] as Map<String, dynamic>?;

    // Miembros
    final rawMembers = json['unit_members'] as List<dynamic>? ?? [];
    final members = rawMembers
        .where((m) => m is Map<String, dynamic>)
        .map((m) => UnitMemberModel.fromJson(m as Map<String, dynamic>))
        .cast<UnitMember>()
        .toList();

    return UnitModel(
      id: _parseInt(json['unit_id']) ?? 0,
      name: json['name']?.toString() ?? 'Sin nombre',
      type: typeName,
      memberCount: members.length,
      leaderName: captainName,
      clubTypeId: _parseInt(json['club_type_id'] ?? clubTypeData?['club_type_id']),
      clubSectionId: _parseInt(
          json['club_section_id'] ?? sectionData?['club_section_id']),
      captainId: json['captain_id']?.toString(),
      secretaryId: json['secretary_id']?.toString(),
      advisorId: json['advisor_id']?.toString(),
      substituteAdvisorId: json['substitute_advisor_id']?.toString(),
      members: members,
    );
  }

  Map<String, dynamic> toJson() => {
        'unit_id': id,
        'name': name,
        'type': type,
        'member_count': memberCount,
        'leader_name': leaderName,
        'club_type_id': clubTypeId,
        'club_section_id': clubSectionId,
        'captain_id': captainId,
        'secretary_id': secretaryId,
        'advisor_id': advisorId,
        'substitute_advisor_id': substituteAdvisorId,
      };

  Unit toEntity() => Unit(
        id: id,
        name: name,
        type: type,
        memberCount: memberCount,
        leaderName: leaderName,
        clubTypeId: clubTypeId,
        clubSectionId: clubSectionId,
        captainId: captainId,
        secretaryId: secretaryId,
        advisorId: advisorId,
        substituteAdvisorId: substituteAdvisorId,
        members: members,
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
