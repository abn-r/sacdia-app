import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/club_info_card.dart';
import '../widgets/current_class_card.dart';
import '../widgets/quick_stats_card.dart';
import '../widgets/upcoming_activities_card.dart';
import '../widgets/welcome_header.dart';

/// Vista principal del dashboard
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: dashboardState.when(
          data: (dashboard) {
            if (dashboard == null) {
              return const Center(
                child: Text(
                  'No se pudo cargar el dashboard',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.sacBlack,
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.sacGreen,
              onRefresh: () async {
                await ref.read(dashboardNotifierProvider.notifier).refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado de bienvenida
                    WelcomeHeader(
                      userName: dashboard.userName,
                      userAvatar: dashboard.userAvatar,
                    ),
                    // Contenido con padding
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.paddingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Información del club
                          ClubInfoCard(
                            clubName: dashboard.clubName,
                            clubType: dashboard.clubType,
                            userRole: dashboard.userRole,
                          ),
                          const SizedBox(height: AppConstants.paddingM),
                          // Clase actual
                          CurrentClassCard(
                            currentClassName: dashboard.currentClassName,
                            classProgress: dashboard.classProgress,
                          ),
                          const SizedBox(height: AppConstants.paddingM),
                          // Estadísticas rápidas
                          QuickStatsCard(
                            honorsCompleted: dashboard.honorsCompleted,
                            honorsInProgress: dashboard.honorsInProgress,
                          ),
                          const SizedBox(height: AppConstants.paddingM),
                          // Actividades próximas
                          UpcomingActivitiesCard(
                            activities: dashboard.upcomingActivities.take(3).toList(),
                          ),
                          const SizedBox(height: AppConstants.paddingM),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.sacGreen,
            ),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppConstants.paddingM),
                  Text(
                    'Error al cargar el dashboard',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.sacBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.paddingS),
                  Text(
                    error.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.paddingL),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(dashboardNotifierProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sacGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingL,
                        vertical: AppConstants.paddingM,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
