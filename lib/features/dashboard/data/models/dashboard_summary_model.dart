import '../../domain/entities/dashboard_summary.dart';

/// Modelo de actividad próxima
class UpcomingActivityModel {
  final int id;
  final String title;

  /// Fecha de la actividad — medianoche local del día correcto.
  final DateTime activityDate;

  /// Hora en formato "HH:mm", tal como llega del backend. Nullable.
  final String? activityTime;

  final String? location;

  const UpcomingActivityModel({
    required this.id,
    required this.title,
    required this.activityDate,
    this.activityTime,
    this.location,
  });

  static DateTime _parseDateOnly(String raw) {
    final datePart = raw.split('T').first;
    final parts = datePart.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return DateTime.now();
    return DateTime(y, m, d);
  }

  factory UpcomingActivityModel.fromJson(Map<String, dynamic> json) {
    return UpcomingActivityModel(
      id: json['id'] as int,
      title: json['title'] as String,
      activityDate: _parseDateOnly(json['activity_date'] as String),
      activityTime: json['activity_time'] as String?,
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'activity_date':
          '${activityDate.year.toString().padLeft(4, '0')}-${activityDate.month.toString().padLeft(2, '0')}-${activityDate.day.toString().padLeft(2, '0')}',
      'activity_time': activityTime,
      'location': location,
    };
  }

  UpcomingActivity toEntity() {
    return UpcomingActivity(
      id: id,
      title: title,
      activityDate: activityDate,
      activityTime: activityTime,
      location: location,
    );
  }
}

/// Modelo de resumen del dashboard
class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.userName,
    super.userAvatar,
    super.clubName,
    super.clubType,
    super.userRole,
    super.currentClassName,
    super.currentClassId,
    required super.classProgress,
    required super.honorsCompleted,
    required super.honorsInProgress,
    required super.upcomingActivities,
  });

  /// Crea un DashboardSummaryModel a partir de datos de la API
  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    final activitiesList = json['upcoming_activities'] as List<dynamic>? ?? [];
    final activities = activitiesList
        .map((item) => UpcomingActivityModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return DashboardSummaryModel(
      userName: json['user_name'] as String,
      userAvatar: json['user_avatar'] as String?,
      clubName: json['club_name'] as String?,
      clubType: json['club_type'] as String?,
      userRole: json['user_role'] as String?,
      currentClassName: json['current_class_name'] as String?,
      currentClassId: json['current_class_id'] as int?,
      // Backend sends class_progress as an integer percentage (0–100).
      // The domain entity and all widgets expect a fraction (0.0–1.0),
      // so we divide by 100 here at the boundary.
      classProgress: ((json['class_progress'] as num?)?.toDouble() ?? 0.0) / 100.0,
      honorsCompleted: json['honors_completed'] as int? ?? 0,
      honorsInProgress: json['honors_in_progress'] as int? ?? 0,
      upcomingActivities: activities.map((a) => a.toEntity()).toList(),
    );
  }

  /// Convierte el modelo a JSON
  Map<String, dynamic> toJson() {
    return {
      'user_name': userName,
      'user_avatar': userAvatar,
      'club_name': clubName,
      'club_type': clubType,
      'user_role': userRole,
      'current_class_name': currentClassName,
      'current_class_id': currentClassId,
      // Serialize back to the API contract format (integer percentage 0–100)
      'class_progress': (classProgress * 100).round(),
      'honors_completed': honorsCompleted,
      'honors_in_progress': honorsInProgress,
      'upcoming_activities': upcomingActivities.map((a) {
        return {
          'id': a.id,
          'title': a.title,
          'activity_date':
              '${a.activityDate.year.toString().padLeft(4, '0')}-${a.activityDate.month.toString().padLeft(2, '0')}-${a.activityDate.day.toString().padLeft(2, '0')}',
          'activity_time': a.activityTime,
          'location': a.location,
        };
      }).toList(),
    };
  }

  /// Crea una copia del modelo con valores actualizados
  DashboardSummaryModel copyWith({
    String? userName,
    String? userAvatar,
    String? clubName,
    String? clubType,
    String? userRole,
    String? currentClassName,
    int? currentClassId,
    double? classProgress,
    int? honorsCompleted,
    int? honorsInProgress,
    List<UpcomingActivity>? upcomingActivities,
  }) {
    return DashboardSummaryModel(
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      clubName: clubName ?? this.clubName,
      clubType: clubType ?? this.clubType,
      userRole: userRole ?? this.userRole,
      currentClassName: currentClassName ?? this.currentClassName,
      currentClassId: currentClassId ?? this.currentClassId,
      classProgress: classProgress ?? this.classProgress,
      honorsCompleted: honorsCompleted ?? this.honorsCompleted,
      honorsInProgress: honorsInProgress ?? this.honorsInProgress,
      upcomingActivities: upcomingActivities ?? this.upcomingActivities,
    );
  }
}
