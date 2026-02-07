import 'package:equatable/equatable.dart';

/// Entidad de actividad próxima
class UpcomingActivity extends Equatable {
  final int id;
  final String title;
  final DateTime date;
  final String? location;

  const UpcomingActivity({
    required this.id,
    required this.title,
    required this.date,
    this.location,
  });

  @override
  List<Object?> get props => [id, title, date, location];
}

/// Entidad de resumen del dashboard
class DashboardSummary extends Equatable {
  final String userName;
  final String? userAvatar;
  final String? clubName;
  final String? clubType;
  final String? userRole;
  final String? currentClassName;
  final double classProgress;
  final int honorsCompleted;
  final int honorsInProgress;
  final List<UpcomingActivity> upcomingActivities;

  const DashboardSummary({
    required this.userName,
    this.userAvatar,
    this.clubName,
    this.clubType,
    this.userRole,
    this.currentClassName,
    required this.classProgress,
    required this.honorsCompleted,
    required this.honorsInProgress,
    required this.upcomingActivities,
  });

  @override
  List<Object?> get props => [
        userName,
        userAvatar,
        clubName,
        clubType,
        userRole,
        currentClassName,
        classProgress,
        honorsCompleted,
        honorsInProgress,
        upcomingActivities,
      ];
}
