import 'package:easy_localization/easy_localization.dart';
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

import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/providers/unread_notifications_count_provider.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/club_info_card.dart';
import '../widgets/current_class_card.dart';
// Stats card kept available for future dashboard experiments.
// import '../widgets/quick_stats_card.dart';
import '../widgets/quick_access_grid.dart';
import '../widgets/upcoming_activities_card.dart';
import '../widgets/membership_status_banner.dart';
import '../widgets/birthday_celebration.dart';
import '../widgets/welcome_header.dart';
import '../../../enrollment/presentation/widgets/enrollment_status_card.dart';

/// Vista principal del dashboard - Estilo "Scout Vibrante"
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardNotifierProvider);
    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    final userGender = user?.metadata?['gender']?.toString();
    final unreadNotificationsCount =
        ref.watch(unreadNotificationsCountProvider);

    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: dashboardState.when(
          data: (dashboard) {
            if (dashboard == null) {
              final statusGrant = membershipGrantForDisplay(
                user?.authorization,
              );
              if (statusGrant?.isPending ?? false) {
                return const _PendingMembershipDashboardState();
              }

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
                      tr('dashboard.load_null_error'),
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
                        userAvatar: dashboard.userAvatar ?? user?.avatar,
                        unreadNotificationsCount: unreadNotificationsCount,
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
                          // Membership status banner (pending/rejected/expired)
                          const MembershipStatusBanner(),

                          // Enrollment status banner
                          const EnrollmentStatusCard(),

                          // Birthday celebration entry point
                          const BirthdayCelebrationGate(),
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

                          // Current class with progress ring.
                          // Uses classWithProgressProvider for accurate % (same
                          // source as "Mis Clases" screen). Falls back to the
                          // dashboard summary's classProgress while loading.
                          CurrentClassCard(
                            currentClassName: dashboard.currentClassName,
                            currentClassId: dashboard.currentClassId,
                            initialIsExpired: dashboard.isCurrentClassExpired,
                            fallbackProgress: dashboard.classProgress,
                          ),
                          const SizedBox(height: 16),

                          // Stats section intentionally hidden for now.
                          // Current available metrics repeat information already
                          // shown by CurrentClassCard or add little action value.
                          // Keep this block as a future reactivation point if the
                          // dashboard summary gains stronger metrics such as
                          // pending validations, role-based tasks, or next-step
                          // actions.
                          //
                          // QuickStatsCard(
                          //   honorsCompleted: dashboard.honorsCompleted,
                          //   honorsInProgress: dashboard.honorsInProgress,
                          //   classProgress: dashboard.classProgress,
                          // ),
                          // const SizedBox(height: 16),

                          // Acceso rápido — launcher de módulos
                          const QuickAccessGrid(),
                          const SizedBox(height: 16),

                          // Demo temporal para escoger motion language.
                          // TODO(remove-before-release): quitar antes de cerrar
                          // la rama de development.
                          const _AnimationDemoLauncher(),
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
                    tr('dashboard.load_error'),
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
                    text: tr('common.retry'),
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

class _PendingMembershipDashboardState extends StatelessWidget {
  const _PendingMembershipDashboardState();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedClock01,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('dashboard.pending_state.title'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr('dashboard.pending_state.body'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.45,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: tr('dashboard.pending_state.profile_action'),
              icon: HugeIcons.strokeRoundedUser,
              onPressed: () => context.go(RouteNames.homeProfile),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimationDemoLauncher extends StatelessWidget {
  const _AnimationDemoLauncher();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(RouteNames.homeAnimationDemo),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.accent.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedFlash,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demo temporal de animaciones',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Compará estilos de motion para decidir cuáles usar.',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: c.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
