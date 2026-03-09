/// Representa un miembro de una unidad dentro de un club SACDIA.
class UnitMember {
  final String id;
  final String name;
  final String surname;
  final String? avatar;

  const UnitMember({
    required this.id,
    required this.name,
    required this.surname,
    this.avatar,
  });

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
