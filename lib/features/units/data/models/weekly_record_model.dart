import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/weekly_record.dart';

// ── Score model ───────────────────────────────────────────────────────────────

/// Modelo de un puntaje por categoría dentro de un registro semanal.
///
/// ```json
/// { "category_id": 1, "category_name": "Puntualidad", "points": 5, "max_points": 5 }
/// ```
class WeeklyRecordScoreModel extends WeeklyRecordScore {
  const WeeklyRecordScoreModel({
    required super.categoryId,
    required super.categoryName,
    required super.points,
    required super.maxPoints,
  });

  factory WeeklyRecordScoreModel.fromJson(Map<String, dynamic> json) {
    return WeeklyRecordScoreModel(
      categoryId: parseInt(json['category_id']) ?? 0,
      categoryName: json['category_name']?.toString() ?? '',
      points: parseInt(json['points']) ?? 0,
      maxPoints: parseInt(json['max_points']) ?? 0,
    );
  }
}

/// Modelo de datos para los registros semanales de una unidad.
///
/// Respuesta esperada del backend:
/// ```json
/// {
///   "record_id": 1,
///   "user_id": "uuid",
///   "week": 12,
///   "attendance": 10,
///   "punctuality": 5,
///   "points": 15,
///   "active": true,
///   "created_at": "2025-03-20T00:00:00Z",
///   "modified_at": "2025-03-20T00:00:00Z",
///   "users": {
///     "user_id": "uuid",
///     "name": "Carlos",
///     "paternal_last_name": "Rodríguez",
///     "user_image": "https://..."
///   }
/// }
/// ```
class WeeklyRecordModel extends WeeklyRecord {
  const WeeklyRecordModel({
    required super.recordId,
    required super.userId,
    required super.week,
    required super.year,
    required super.attendance,
    required super.punctuality,
    required super.points,
    super.active,
    super.userName,
    super.userLastName,
    super.userImage,
    super.scores,
  });

  factory WeeklyRecordModel.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>? ?? {};

    // Parse enriched scores from backend
    final rawScores = json['scores'] as List<dynamic>? ?? [];
    final scores = rawScores
        .whereType<Map<String, dynamic>>()
        .map((s) => WeeklyRecordScoreModel.fromJson(s))
        .cast<WeeklyRecordScore>()
        .toList();

    return WeeklyRecordModel(
      recordId: parseInt(json['record_id']) ?? 0,
      userId: (json['user_id'] ?? users['user_id'] ?? '').toString(),
      week: parseInt(json['week']) ?? 0,
      year: parseInt(json['year']) ?? DateTime.now().year,
      attendance: parseInt(json['attendance']) ?? 0,
      punctuality: parseInt(json['punctuality']) ?? 0,
      points: parseInt(json['points']) ?? 0,
      active: json['active'] as bool? ?? true,
      userName: users['name']?.toString(),
      userLastName: users['paternal_last_name']?.toString(),
      userImage: users['user_image']?.toString(),
      scores: scores,
    );
  }

  Map<String, dynamic> toJson() => {
        'record_id': recordId,
        'user_id': userId,
        'week': week,
        'year': year,
        'attendance': attendance,
        'punctuality': punctuality,
        'points': points,
        'active': active,
      };

  WeeklyRecord toEntity() => WeeklyRecord(
        recordId: recordId,
        userId: userId,
        week: week,
        year: year,
        attendance: attendance,
        punctuality: punctuality,
        points: points,
        active: active,
        userName: userName,
        userLastName: userLastName,
        userImage: userImage,
        scores: scores,
      );

}
