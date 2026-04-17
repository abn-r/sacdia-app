/// Un puntaje por categoría dentro de un registro semanal.
class WeeklyRecordScore {
  final int categoryId;
  final String categoryName;
  final int points;
  final int maxPoints;

  const WeeklyRecordScore({
    required this.categoryId,
    required this.categoryName,
    required this.points,
    required this.maxPoints,
  });
}

/// Representa un registro semanal de asistencia y puntos de un miembro.
class WeeklyRecord {
  final int recordId;
  final String userId;
  final int week;

  /// Año al que pertenece el registro (ISO 8601, puede diferir de calendar year
  /// para semanas que cruzan el fin de año).
  final int year;

  /// Puntos de asistencia para la semana.
  final int attendance;

  /// Puntos de puntualidad para la semana.
  final int punctuality;

  /// Puntos totales para la semana (suma de todas las categorías).
  final int points;

  final bool active;

  /// Nombre del usuario (puede ser null si no viene en la respuesta).
  final String? userName;

  /// Apellido paterno del usuario.
  final String? userLastName;

  /// Foto del usuario.
  final String? userImage;

  /// Puntajes desglosados por categoría (enriquecidos desde el backend).
  final List<WeeklyRecordScore> scores;

  const WeeklyRecord({
    required this.recordId,
    required this.userId,
    required this.week,
    required this.year,
    required this.attendance,
    required this.punctuality,
    required this.points,
    this.active = true,
    this.userName,
    this.userLastName,
    this.userImage,
    this.scores = const [],
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
