import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/club_info_card.dart';
import '../widgets/current_class_card.dart';
import '../widgets/quick_stats_card.dart';
import '../widgets/quick_access_grid.dart';
import '../widgets/upcoming_activities_card.dart';
import '../widgets/membership_status_banner.dart';
import '../widgets/welcome_header.dart';
import '../../../enrollment/presentation/widgets/enrollment_status_card.dart';

/// Vista principal del dashboard - Estilo "Scout Vibrante"
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardNotifierProvider);
    final authAvatar = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull?.avatar),
    );
    final userGender = ref.watch(
      profileNotifierProvider.select((v) => v.valueOrNull?.gender),
    );

    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: dashboardState.when(
          data: (dashboard) {
            if (dashboard == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedDashboardSquare01,
                        size: 56,
                        color: c.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudo cargar el dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            final hPad = Responsive.horizontalPadding(context);

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await ref.read(dashboardNotifierProvider.notifier).refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header — animates in as item 0
                    StaggeredListItem(
                      index: 0,
                      initialDelay: const Duration(milliseconds: 60),
                      child: WelcomeHeader(
                        userName: dashboard.userName,
                        userAvatar: dashboard.userAvatar ?? authAvatar,
                        onNotificationsTap: () =>
                            context.push(RouteNames.notificationsInbox),
                      ),
                    ),

                    // Content cards with staggered entrance
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: StaggeredColumn(
                        initialDelay: const Duration(milliseconds: 120),
                        staggerDelay: const Duration(milliseconds: 80),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // Membership status banner (pending/rejected/expired)
                          const MembershipStatusBanner(),
                          const SizedBox(height: 16),

                          // Enrollment status banner
                          const EnrollmentStatusCard(),
                          const SizedBox(height: 16),

                          // Club info
                          ClubInfoCard(
                            clubName: dashboard.clubName,
                            clubType: dashboard.clubType,
                            userRole: RoleUtils.translate(
                              dashboard.userRole,
                              gender: userGender,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Current class with progress ring
                          CurrentClassCard(
                            currentClassName: dashboard.currentClassName,
                            classProgress: dashboard.classProgress,
                          ),
                          const SizedBox(height: 16),

                          // Quick stats row (animated counters inside)
                          QuickStatsCard(
                            honorsCompleted: dashboard.honorsCompleted,
                            honorsInProgress: dashboard.honorsInProgress,
                          ),
                          const SizedBox(height: 16),

                          // Quick access grid
                          const QuickAccessGrid(),
                          const SizedBox(height: 16),

                          // Upcoming activities
                          UpcomingActivitiesCard(
                            activities:
                                dashboard.upcomingActivities.take(3).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: SacLoading()),
          error: (error, stack) => Center(
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
                    'Error al cargar el dashboard',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SacButton.primary(
                    text: 'Reintentar',
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: () {
                      ref.read(dashboardNotifierProvider.notifier).refresh();
                    },
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
