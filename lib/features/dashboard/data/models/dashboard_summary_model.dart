import '../../domain/entities/dashboard_summary.dart';

/// Modelo de actividad próxima
class UpcomingActivityModel {
  final int id;
  final String title;
  final DateTime date;
  final String? location;

  const UpcomingActivityModel({
    required this.id,
    required this.title,
    required this.date,
    this.location,
  });

  factory UpcomingActivityModel.fromJson(Map<String, dynamic> json) {
    return UpcomingActivityModel(
      id: json['id'] as int,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'location': location,
    };
  }

  UpcomingActivity toEntity() {
    return UpcomingActivity(
      id: id,
      title: title,
      date: date,
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
      // Serialize back to the API contract format (integer percentage 0–100)
      'class_progress': (classProgress * 100).round(),
      'honors_completed': honorsCompleted,
      'honors_in_progress': honorsInProgress,
      'upcoming_activities': upcomingActivities.map((a) {
        return {
          'id': a.id,
          'title': a.title,
          'date': a.date.toIso8601String(),
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
      classProgress: classProgress ?? this.classProgress,
      honorsCompleted: honorsCompleted ?? this.honorsCompleted,
      honorsInProgress: honorsInProgress ?? this.honorsInProgress,
      upcomingActivities: upcomingActivities ?? this.upcomingActivities,
    );
  }
}
