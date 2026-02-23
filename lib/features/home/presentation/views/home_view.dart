import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../../core/utils/extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/recent_activity_list.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardNotifierProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: dashboardState.when(
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 56,
                    color: AppColors.error,
                  ),
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
                    error.toString(),
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
                    onPressed: () =>
                        ref.read(dashboardNotifierProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
          ),
          data: (dashboard) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.read(dashboardNotifierProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Bienvenido de nuevo!',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
                      IconButton(
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedLogout01,
                          color: AppColors.lightTextTertiary,
                          size: 24,
                        ),
                        onPressed: () => _handleLogout(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (dashboard != null) ...[
                    DashboardCard(
                      title: 'Especialidades completadas',
                      value: dashboard.honorsCompleted.toString(),
                      icon: HugeIcons.strokeRoundedTaskDone01,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedClock05,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Actividades próximas',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (dashboard.upcomingActivities.isNotEmpty)
                      RecentActivityList(
                        activities: dashboard.upcomingActivities
                            .map((a) => a.title)
                            .toList(),
                      )
                    else
                      SacCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No hay actividades próximas',
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
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'Cerrar sesión',
      content: '¿Estás seguro que deseas cerrar sesión?',
      confirmLabel: 'Cerrar sesión',
      confirmIsDestructive: true,
    );

    if (confirmed == true) {
      final success = await ref.read(authNotifierProvider.notifier).signOut();
      if (success && context.mounted) {
        context.showSnackBar('Sesión cerrada correctamente');
      } else if (!success && context.mounted) {
        context.showSnackBar('Error al cerrar sesión');
      }
    }
  }
}
