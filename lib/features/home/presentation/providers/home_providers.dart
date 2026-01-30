import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dashboard_entity.dart';

/// Estado del Home 
class HomeState {
  final DashboardEntity? dashboardData;
  final bool isLoading;
  final String? errorMessage;

  HomeState({
    this.dashboardData,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Crea una copia del estado con nuevos valores
  HomeState copyWith({
    DashboardEntity? dashboardData,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HomeState(
      dashboardData: dashboardData ?? this.dashboardData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier para manejar el estado de la pantalla principal
class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(HomeState());

  /// Carga los datos iniciales del dashboard
  Future<void> loadDashboardData() async {
    // Por ahora usamos datos simulados
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // Simulamos una carga de datos
      await Future.delayed(const Duration(seconds: 1));
      
      // Datos de prueba para el dashboard
      final dashboardData = DashboardEntity(
        welcomeMessage: '¡Bienvenido de nuevo!',
        pendingTasks: 5,
        recentActivities: [
          'Actualización de perfil',
          'Nuevo mensaje recibido',
          'Tarea completada'
        ],
        hasNotifications: true,
      );
      
      state = state.copyWith(
        dashboardData: dashboardData,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al cargar los datos: $e',
      );
    }
  }

  /// Marca las notificaciones como leídas
  void markNotificationsAsRead() {
    if (state.dashboardData != null) {
      final updatedDashboard = DashboardEntity(
        welcomeMessage: state.dashboardData!.welcomeMessage,
        pendingTasks: state.dashboardData!.pendingTasks,
        recentActivities: state.dashboardData!.recentActivities,
        hasNotifications: false,
      );
      
      state = state.copyWith(dashboardData: updatedDashboard);
    }
  }
}

/// Provider para HomeNotifier
final homeNotifierProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier();
});
