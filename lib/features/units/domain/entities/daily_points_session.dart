/// Representa la sesión de puntos diarios de una unidad.
///
/// Cada unidad puede tener UN solo registro de puntos por día.
/// La regla atómica es: si algún miembro tiene puntos > 0,
/// TODOS los miembros deben tener puntos > 0. Si todos tienen 0,
/// la sesión en blanco también es válida.
class DailyPointsSession {
  final DateTime date;

  /// Mapa de memberId → puntos asignados en esta sesión.
  final Map<String, int> pointsByMemberId;

  /// Puntos máximos que puede tener cada miembro por sesión.
  final int maxPoints;

  const DailyPointsSession({
    required this.date,
    required this.pointsByMemberId,
    required this.maxPoints,
  });

  /// Retorna true si todos los miembros tienen puntos asignados (> 0).
  bool get isComplete =>
      pointsByMemberId.isNotEmpty &&
      pointsByMemberId.values.every((p) => p > 0);

  /// Retorna true si la sesión es válida para guardar:
  /// - Todos los miembros tienen 0 (sesión en blanco), o
  /// - Todos los miembros tienen puntos > 0 (regla atómica cumplida).
  ///
  /// Es inválida si al menos uno tiene > 0 y al menos uno tiene 0.
  bool get isValid {
    if (pointsByMemberId.isEmpty) return true;
    final anyWithPoints = pointsByMemberId.values.any((p) => p > 0);
    final anyWithZero = pointsByMemberId.values.any((p) => p == 0);
    // Inválido: mezcla de cero y no-cero
    if (anyWithPoints && anyWithZero) return false;
    return true;
  }

  DailyPointsSession copyWith({
    DateTime? date,
    Map<String, int>? pointsByMemberId,
    int? maxPoints,
  }) {
    return DailyPointsSession(
      date: date ?? this.date,
      pointsByMemberId: pointsByMemberId ?? this.pointsByMemberId,
      maxPoints: maxPoints ?? this.maxPoints,
    );
  }
}
