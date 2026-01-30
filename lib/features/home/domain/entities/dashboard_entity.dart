import 'package:equatable/equatable.dart';

/// Entidad para los datos del dashboard en la pantalla principal
class DashboardEntity extends Equatable {
  final String welcomeMessage;
  final int pendingTasks;
  final List<String> recentActivities;
  final bool hasNotifications;

  const DashboardEntity({
    required this.welcomeMessage,
    this.pendingTasks = 0,
    this.recentActivities = const [],
    this.hasNotifications = false,
  });

  @override
  List<Object?> get props => [
        welcomeMessage,
        pendingTasks,
        recentActivities,
        hasNotifications,
      ];
}
