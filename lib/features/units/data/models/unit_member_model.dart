import '../../domain/entities/unit_member.dart';

/// Modelo de datos para los miembros de una unidad.
///
/// Respuesta esperada del backend dentro de `unit_members`:
/// ```json
/// {
///   "unit_member_id": 1,
///   "user_id": "uuid",
///   "active": true,
///   "created_at": "2025-01-01T00:00:00Z",
///   "users": {
///     "user_id": "uuid",
///     "name": "Carlos",
///     "paternal_last_name": "Rodríguez",
///     "maternal_last_name": "García",
///     "user_image": "https://..."
///   }
/// }
/// ```
class UnitMemberModel extends UnitMember {
  /// ID del registro en la tabla `unit_members`.
  final int unitMemberId;

  const UnitMemberModel({
    required this.unitMemberId,
    required super.id,
    required super.name,
    required super.surname,
    super.avatar,
  });

  factory UnitMemberModel.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>? ?? {};

    final userId = (json['user_id'] ?? users['user_id'] ?? '').toString();
    final name = (users['name'] ?? '').toString();
    final paternal =
        (users['paternal_last_name'] ?? users['p_lastname'] ?? '').toString();
    final maternal =
        (users['maternal_last_name'] ?? users['m_lastname'] ?? '').toString();
    // El apellido display es paternal; maternal queda disponible si se necesita.
    final surname = [paternal, maternal]
        .where((s) => s.isNotEmpty)
        .join(' ');

    final avatar = (users['user_image'] ?? users['avatar'])?.toString();
    final unitMemberId = _parseInt(json['unit_member_id']) ?? 0;

    return UnitMemberModel(
      unitMemberId: unitMemberId,
      id: userId,
      name: name,
      surname: surname.isNotEmpty ? surname : 'Sin apellido',
      avatar: avatar,
    );
  }

  Map<String, dynamic> toJson() => {
        'unit_member_id': unitMemberId,
        'user_id': id,
        'name': name,
        'surname': surname,
        'avatar': avatar,
      };

  UnitMember toEntity() => UnitMember(
        id: id,
        name: name,
        surname: surname,
        avatar: avatar,
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
