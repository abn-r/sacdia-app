/// Representa una unidad dentro de un club SACDIA
/// (Conquistadores, Aventureros o Guías Mayores).
class Unit {
  final int id;
  final String name;
  final String type;
  final int memberCount;
  final String? leaderName;

  const Unit({
    required this.id,
    required this.name,
    required this.type,
    required this.memberCount,
    this.leaderName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Unit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
