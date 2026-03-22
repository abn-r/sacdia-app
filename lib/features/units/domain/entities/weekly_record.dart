/// Representa un registro semanal de asistencia y puntos de un miembro.
class WeeklyRecord {
  final int recordId;
  final String userId;
  final int week;

  /// Puntos de asistencia para la semana.
  final int attendance;

  /// Puntos de puntualidad para la semana.
  final int punctuality;

  /// Puntos totales para la semana.
  final int points;

  final bool active;

  /// Nombre del usuario (puede ser null si no viene en la respuesta).
  final String? userName;

  /// Apellido paterno del usuario.
  final String? userLastName;

  /// Foto del usuario.
  final String? userImage;

  const WeeklyRecord({
    required this.recordId,
    required this.userId,
    required this.week,
    required this.attendance,
    required this.punctuality,
    required this.points,
    this.active = true,
    this.userName,
    this.userLastName,
    this.userImage,
  });

  /// Nombre completo del usuario (si está disponible).
  String get fullName {
    final parts = [userName, userLastName].where((s) => s != null && s.isNotEmpty);
    return parts.join(' ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WeeklyRecord && other.recordId == recordId;

  @override
  int get hashCode => recordId.hashCode;
}
