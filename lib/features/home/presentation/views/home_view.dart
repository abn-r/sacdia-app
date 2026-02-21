import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../../core/utils/extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/home_providers.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/recent_activity_list.dart';

/// Vista principal de la aplicación después del login - Estilo "Scout Vibrante"
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(homeNotifierProvider.notifier).loadDashboardData());
  }

  Future<void> _handleLogout() async {
    final confirmed = await SacDialog.show(
      context,
      title: 'Cerrar sesión',
      content: '¿Estás seguro que deseas cerrar sesión?',
      confirmLabel: 'Cerrar sesión',
      confirmIsDestructive: true,
    );

    if (confirmed == true) {
      try {
        await ref.read(authNotifierProvider.notifier).signOut();

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('supabase.auth.token');
        await prefs.remove('supabase.auth.refresh_token');
        await prefs.remove('supabase.auth.expires_at');
        await prefs.remove('supabase.auth.expires_in');
        await prefs.remove('supabase.auth.user');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sesión cerrada correctamente'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeNotifierProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: homeState.isLoading
            ? const Center(child: SacLoading())
            : homeState.errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedAlert02,
                              size: 56, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(
                            'Error al cargar datos',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            homeState.errorMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.lightTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SacButton.primary(
                            text: 'Reintentar',
                            icon: HugeIcons.strokeRoundedRefresh,
                            onPressed: () {
                              ref
                                  .read(homeNotifierProvider.notifier)
                                  .loadDashboardData();
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      await ref
                          .read(homeNotifierProvider.notifier)
                          .loadDashboardData();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(hPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with greeting and actions
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      homeState.dashboardData
                                              ?.welcomeMessage ??
                                          '¡Bienvenido!',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (user != null)
                                      Text(
                                        user.name ?? user.email,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: AppColors.lightTextSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              // Notification bell
                              if (homeState.dashboardData?.hasNotifications ??
                                  false)
                                IconButton(
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedNotification02,
                                    color: AppColors.accent,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(homeNotifierProvider.notifier)
                                        .markNotificationsAsRead();
                                    context.showSnackBar(
                                        'Notificaciones marcadas como leídas');
                                  },
                                )
                              else
                                IconButton(
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedNotification01,
                                    color: AppColors.lightTextTertiary,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    context.showSnackBar(
                                        'No tienes notificaciones nuevas');
                                  },
                                ),
                              IconButton(
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedLogout01,
                                  color: AppColors.lightTextTertiary,
                                  size: 24,
                                ),
                                onPressed: _handleLogout,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          if (homeState.dashboardData != null) ...[
                            DashboardCard(
                              title: 'Tareas pendientes',
                              value: homeState.dashboardData!.pendingTasks
                                  .toString(),
                              icon: HugeIcons.strokeRoundedTaskDone01,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 20),

                            // Recent activity header
                            Row(
                              children: [
                                HugeIcon(icon: HugeIcons.strokeRoundedClock05,
                                    size: 20, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Actividad reciente',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (homeState
                                .dashboardData!.recentActivities.isNotEmpty)
                              RecentActivityList(
                                activities:
                                    homeState.dashboardData!.recentActivities,
                              )
                            else
                              SacCard(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text(
                                      'No hay actividades recientes',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
