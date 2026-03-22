import '../../domain/entities/weekly_record.dart';

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
    required super.attendance,
    required super.punctuality,
    required super.points,
    super.active,
    super.userName,
    super.userLastName,
    super.userImage,
  });

  factory WeeklyRecordModel.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>? ?? {};

    return WeeklyRecordModel(
      recordId: _parseInt(json['record_id']) ?? 0,
      userId: (json['user_id'] ?? users['user_id'] ?? '').toString(),
      week: _parseInt(json['week']) ?? 0,
      attendance: _parseInt(json['attendance']) ?? 0,
      punctuality: _parseInt(json['punctuality']) ?? 0,
      points: _parseInt(json['points']) ?? 0,
      active: json['active'] as bool? ?? true,
      userName: users['name']?.toString(),
      userLastName: users['paternal_last_name']?.toString(),
      userImage: users['user_image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'record_id': recordId,
        'user_id': userId,
        'week': week,
        'attendance': attendance,
        'punctuality': punctuality,
        'points': points,
        'active': active,
      };

  WeeklyRecord toEntity() => WeeklyRecord(
        recordId: recordId,
        userId: userId,
        week: week,
        attendance: attendance,
        punctuality: punctuality,
        points: points,
        active: active,
        userName: userName,
        userLastName: userLastName,
        userImage: userImage,
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
