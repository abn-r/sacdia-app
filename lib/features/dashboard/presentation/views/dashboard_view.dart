import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../post_registration/presentation/utils/acting_copy.dart';
import '../../../notifications/presentation/providers/unread_notifications_count_provider.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/club_info_card.dart';
import '../widgets/current_class_card.dart';
// Stats card kept available for future dashboard experiments.
// import '../widgets/quick_stats_card.dart';
import '../widgets/quick_access_grid.dart';
import '../../../activities/presentation/views/activity_detail_view.dart';
import '../widgets/upcoming_activities_card.dart';
import '../widgets/membership_status_banner.dart';
import '../widgets/birthday_celebration.dart';
import '../widgets/welcome_header.dart';
import '../../../enrollment/presentation/widgets/enrollment_status_card.dart';
import '../../../investiture_requests/presentation/views/authorizer_requests_view.dart';

/// Vista principal del dashboard - Estilo "Scout Vibrante"
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    // El pastor sin club no tiene inicio de miembro: su inicio son las
    // autorizaciones. Se decide antes de leer el resumen del dashboard, que
    // pertenece a un club.
    if (isPastorWithoutClub(user)) return const AuthorizerRequestsView();

    final dashboardState = ref.watch(dashboardNotifierProvider);
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
              if (statusGrant?.isInactive ?? false) {
                // Ghost: member belongs to a club but not enrolled this year.
                // Show dedicated empty state with the ghost banner.
                return const _GhostMembershipDashboardState();
              }

              if (isGuardianWithoutClub(user)) {
                // Tutor sin club (post-registro «solo tutor»): su inicio es la
                // familia, no un resumen de club.
                return const _GuardianWithoutClubDashboardState();
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
              color: SacAccent.of(context).color,
              onRefresh: () async {
                await ref.read(dashboardNotifierProvider.notifier).refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header
                    WelcomeHeader(
                      userName: dashboard.userName,
                      userAvatar: dashboard.userAvatar ?? user?.avatar,
                      unreadNotificationsCount: unreadNotificationsCount,
                      onNotificationsTap: () =>
                          context.push(RouteNames.notificationsInbox),
                    ),

                    // Content cards
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Column(
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

                          // Upcoming activities
                          UpcomingActivitiesCard(
                            activities:
                                dashboard.upcomingActivities.take(3).toList(),
                            onActivityTap: (activity) {
                              Navigator.push(
                                context,
                                SacSharedAxisRoute(
                                  builder: (context) => ActivityDetailView(
                                    activityId: activity.id,
                                  ),
                                ),
                              );
                            },
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

/// Solicitud de membresía pendiente.
///
/// Mientras un tutor actúa por un menor (su consentimiento sigue pendiente) el
/// texto pasa a tercera persona con el nombre del menor, no menciona la
/// formación personal y la acción lleva a Mi familia: primero se sale de
/// "actuar por" porque esas rutas están bloqueadas con un menor activo.
class _PendingMembershipDashboardState extends ConsumerWidget {
  const _PendingMembershipDashboardState();

  /// Sale de "actuar por" y abre Mi familia del tutor.
  Future<void> _openFamily(BuildContext context, WidgetRef ref) async {
    // El router sobrevive al cambio de perfil; el `context` puede no hacerlo.
    final router = GoRouter.of(context);
    await ref.read(authNotifierProvider.notifier).switchProfile(null);
    router.push(RouteNames.family);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final actingName = actingCopyName(ref);
    final acting = actingName != null;

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
                color: SacAccent.of(context).color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedClock01,
                  size: 36,
                  color: SacAccent.of(context).color,
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
              acting
                  ? tr('dashboard.pending_state.body_acting',
                      namedArgs: {'name': actingName})
                  : tr('dashboard.pending_state.body'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.45,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (acting)
              SacButton.primary(
                text: tr('dashboard.pending_state.family_action_acting'),
                icon: HugeIcons.strokeRoundedUserGroup,
                onPressed: () => _openFamily(context, ref),
              )
            else
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

/// Estado del dashboard para usuarios ghost (miembro del club pero sin
/// inscripción para el año eclesiástico actual).
class _GhostMembershipDashboardState extends StatelessWidget {
  const _GhostMembershipDashboardState();

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Banner de no inscrito: copy informativo, sin autoinscripción.
            const MembershipStatusBanner(),
          ],
        ),
      ),
    );
  }
}

/// Estado del dashboard para un tutor sin club: invita a gestionar la familia.
///
/// No hay ruta para unirse a un club tras el post-registro (el selector de
/// club solo vive dentro de ese flujo y de las transferencias entre clubes),
/// así que la única acción es «Mi familia».
class _GuardianWithoutClubDashboardState extends StatelessWidget {
  const _GuardianWithoutClubDashboardState();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final hPad = Responsive.horizontalPadding(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedUserGroup,
                  size: 36,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('dashboard.guardian_no_club.title'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr('dashboard.guardian_no_club.subtitle'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.45,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: tr('dashboard.guardian_no_club.family_action'),
              icon: HugeIcons.strokeRoundedUserGroup,
              onPressed: () => context.push(RouteNames.family),
            ),
          ],
        ),
      ),
    );
  }
}
