/// Rol de una persona dentro de la unidad, para la planilla de puntos.
enum UnitMemberRole {
  captain,
  secretary,
  member;

  /// Parsea el `unit_role` del backend. Desconocido o ausente = [member].
  static UnitMemberRole parse(Object? raw) {
    switch (raw?.toString()) {
      case 'captain':
        return UnitMemberRole.captain;
      case 'secretary':
        return UnitMemberRole.secretary;
      default:
        return UnitMemberRole.member;
    }
  }
}

/// Representa un miembro de una unidad dentro de un club SACDIA.
class UnitMember {
  /// ID del registro `unit_members`, necesario para remover membresías.
  final int? unitMemberId;

  final String id;
  final String name;
  final String surname;
  final String? avatar;

  /// Rol en la unidad (capitán, secretario o miembro).
  final UnitMemberRole role;

  const UnitMember({
    this.unitMemberId,
    required this.id,
    required this.name,
    required this.surname,
    this.avatar,
    this.role = UnitMemberRole.member,
  });

  /// Copia con otro [role].
  UnitMember withRole(UnitMemberRole newRole) => UnitMember(
        unitMemberId: unitMemberId,
        id: id,
        name: name,
        surname: surname,
        avatar: avatar,
        role: newRole,
      );

  /// Nombre completo del miembro.
  String get fullName => '$name $surname';

  /// Iniciales para usar en avatares cuando no hay foto.
  /// Toma la primera letra del nombre y la primera del apellido.
  String get initials {
    final n = name.isNotEmpty ? name[0].toUpperCase() : '';
    final s = surname.isNotEmpty ? surname[0].toUpperCase() : '';
    return '$n$s';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UnitMember && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
