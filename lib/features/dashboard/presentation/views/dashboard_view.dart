import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';

import '../../../auth/domain/entities/pending_club_membership.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../post_registration/presentation/providers/post_registration_providers.dart';
import '../../../post_registration/presentation/utils/acting_copy.dart';
import '../../../notifications/presentation/providers/unread_notifications_count_provider.dart';
import '../providers/dashboard_providers.dart';
import '../providers/dashboard_pending_provider.dart';
import '../widgets/class_hero_card.dart';
import '../widgets/dashboard_club_line.dart';
import '../widgets/for_you_section.dart';
import '../widgets/next_activity_card.dart';
import '../widgets/pending_tasks_card.dart';
import '../widgets/current_class_card.dart';
// Stats card kept available for future dashboard experiments.
// import '../widgets/quick_stats_card.dart';
import '../widgets/quick_access_grid.dart';
import '../widgets/quick_access_items.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../../activities/presentation/views/activity_detail_view.dart';
import '../widgets/upcoming_activities_card.dart';
import '../widgets/membership_status_banner.dart';
import '../widgets/birthday_celebration.dart';
import '../home_spacing.dart';
import '../widgets/welcome_header.dart';
import '../../../enrollment/presentation/providers/enrollment_providers.dart';
import '../../../enrollment/presentation/widgets/enrollment_status_card.dart';
import '../../../coordinator/presentation/views/coordinator_hub_view.dart';
import '../../../investiture_requests/presentation/views/authorizer_requests_view.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Vista principal del dashboard - Estilo "Scout Vibrante"
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      authNotifierProvider.select((v) => v.value),
    );
    // El coordinador sin club tampoco: su inicio es el panel de coordinación
    // (manda sobre pastor y tutor sin club; «Mi familia» sigue en el perfil).
    if (isCoordinatorWithoutClub(user)) return const CoordinatorHubView();

    // El pastor sin club no tiene inicio de miembro: su inicio son las
    // autorizaciones. Se decide antes de leer el resumen del dashboard, que
    // pertenece a un club.
    if (isPastorWithoutClub(user)) return const AuthorizerRequestsView();

    final dashboardState = ref.watch(dashboardNotifierProvider);
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
              // Adolescente supervisado con solicitud propia en revisión
              // (`/auth/me.pending_club_membership`): el texto lleva el club.
              // Tenga o no una concesión pendiente en `authorization`.
              final pendingClub = (user?.isSupervisedTeen ?? false)
                  ? user?.pendingClubMembership
                  : null;
              if (statusGrant?.isPending ?? false) {
                return _PendingMembershipDashboardState(
                    pendingClub: pendingClub);
              }
              if (pendingClub != null) {
                return _PendingMembershipDashboardState(
                    pendingClub: pendingClub);
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

              return SacErrorState(
                title: tr('dashboard.load_null_error'),
                onRetry: () =>
                    ref.read(dashboardNotifierProvider.notifier).refresh(),
              );
            }

            final hPad = Responsive.horizontalPadding(context);

            return RefreshIndicator(
              color: SacAccent.of(context).color,
              onRefresh: () async {
                await ref.read(dashboardNotifierProvider.notifier).refresh();
                // Auxiliary staff card: refetch with the summary.
                ref.invalidate(dashboardPendingProvider);
                // The annual enrollment may have been reviewed meanwhile.
                ref.invalidate(currentEnrollmentProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header (+ club selector line under the name)
                    WelcomeHeader(
                      userName: dashboard.userName,
                      userAvatar: dashboard.userAvatar ?? user?.avatar,
                      unreadNotificationsCount: unreadNotificationsCount,
                      onNotificationsTap: () =>
                          context.push(RouteNames.notificationsInbox),
                      subtitle: DashboardClubLine(clubName: dashboard.clubName),
                    ),

                    // Content cards: two compositions (staff vs member).
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: isClubStaffMode(user)
                            ? _staffChildren(context, dashboard)
                            : _memberChildren(context, ref, dashboard),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: SacLoading()),
          error: (error, stack) => SacErrorState(
            title: tr('dashboard.load_error'),
            message: userErrorMessage(error),
            onRetry: () =>
                ref.read(dashboardNotifierProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

/// Quick-access tiles the member home does not repeat (already in «Para ti»).
const Set<String> _memberQuickAccessExcludedRoutes = {
  RouteNames.homeResources,
};

void _openActivity(BuildContext context, UpcomingActivity activity) {
  Navigator.push(
    context,
    SacSharedAxisRoute(
      builder: (context) => ActivityDetailView(activityId: activity.id),
    ),
  );
}

/// Banners shared by both home compositions.
///
/// Spacing rule for the home: see [HomeSpacing]. A header gap under the club
/// line, then every card or banner keeps [HomeSpacing.card] below itself.
/// Self-hiding widgets bring their own gap, so a hidden one leaves none.
///
/// On the staff home the annual enrollment task is a row of «Pendientes»
/// ([showEnrollmentTask] false); the banner only keeps its informative states.
List<Widget> _statusBanners({required bool showEnrollmentTask}) => [
      const SizedBox(height: HomeSpacing.header),

      // Membership status banner (pending/rejected/expired)
      const MembershipStatusBanner(),

      // Enrollment status banner
      EnrollmentStatusCard(
        showTask: showEnrollmentTask,
        bottomSpacing: HomeSpacing.card,
      ),

      // Birthday celebration entry point
      const BirthdayCelebrationGate(),
    ];

/// Staff home: pending tasks (only when there are any), current class, the
/// full quick-access launcher and the upcoming activities list.
List<Widget> _staffChildren(BuildContext context, DashboardSummary dashboard) {
  return [
    ..._statusBanners(showEnrollmentTask: false),

    // Pending tasks (with the annual enrollment as a row): hides itself (and
    // its gap) when there is nothing to attend.
    const PendingTasksCard(bottomSpacing: HomeSpacing.card),

    // Current class with progress ring. Uses classWithProgressProvider for
    // accurate % (same source as "Mis Clases"), falling back to the dashboard
    // summary's classProgress while loading.
    CurrentClassCard(
      currentClassName: dashboard.currentClassName,
      currentClassId: dashboard.currentClassId,
      initialIsExpired: dashboard.isCurrentClassExpired,
      fallbackProgress: dashboard.classProgress,
    ),
    const SizedBox(height: HomeSpacing.section),

    // Acceso rápido — launcher de módulos
    const QuickAccessGrid(),
    const SizedBox(height: HomeSpacing.section),

    // Upcoming activities
    UpcomingActivitiesCard(
      activities: dashboard.upcomingActivities.take(3).toList(),
      onActivityTap: (activity) => _openActivity(context, activity),
    ),
    const SizedBox(height: 24),
  ];
}

/// Member home: class hero, next activity, «Para ti» and (only when there is
/// anything left to show) the quick-access launcher without «Recursos».
List<Widget> _memberChildren(
  BuildContext context,
  WidgetRef ref,
  DashboardSummary dashboard,
) {
  final className = dashboard.currentClassName?.trim();
  final hasClass = className != null && className.isNotEmpty;
  final hasQuickAccess = ref
      .watch(visibleQuickAccessItemsProvider)
      .any((item) => !_memberQuickAccessExcludedRoutes.contains(item.route));

  return [
    ..._statusBanners(showEnrollmentTask: true),

    // Class hero, or the compact card when the user has no class.
    if (hasClass)
      ClassHeroCard(
        currentClassName: className,
        currentClassId: dashboard.currentClassId,
        initialIsExpired: dashboard.isCurrentClassExpired,
        fallbackProgress: dashboard.classProgress,
      )
    else
      CurrentClassCard(
        currentClassName: dashboard.currentClassName,
        currentClassId: dashboard.currentClassId,
        initialIsExpired: dashboard.isCurrentClassExpired,
        fallbackProgress: dashboard.classProgress,
      ),
    const SizedBox(height: HomeSpacing.card),

    NextActivityCard(
      activity: nextUpcomingActivity(dashboard.upcomingActivities),
      onTap: (activity) => _openActivity(context, activity),
    ),
    const SizedBox(height: 24),

    const ForYouSection(),
    if (hasQuickAccess) ...const [
      SizedBox(height: 24),
      QuickAccessGrid(excludedRoutes: _memberQuickAccessExcludedRoutes),
    ],
    const SizedBox(height: 24),
  ];
}

/// Solicitud de membresía pendiente.
///
/// Mientras un tutor actúa por un menor (su consentimiento sigue pendiente) el
/// texto pasa a tercera persona con el nombre del menor, no menciona la
/// formación personal y la acción lleva a Mi familia: primero se sale de
/// "actuar por" porque esas rutas están bloqueadas con un menor activo.
class _PendingMembershipDashboardState extends ConsumerWidget {
  const _PendingMembershipDashboardState({this.pendingClub});

  /// Solicitud propia con el nombre del club (adolescente supervisado sin
  /// club). Nulo en el resto de casos: se usa el texto genérico.
  final PendingClubMembership? pendingClub;

  /// Sale de "actuar por" y abre Mi familia del tutor.
  ///
  /// `switchProfile(null)` termina cuando la sesión ya salió, pero el estado de
  /// auth sigue en carga mientras `/auth/me` del tutor se vuelve a pedir. Con
  /// auth cargando el `redirect` del router manda a splash y de ahí al inicio,
  /// así que un `push` hecho antes se pierde. Se espera a que auth quede
  /// resuelto y solo entonces se abre Mi familia.
  Future<void> _openFamily(BuildContext context, WidgetRef ref) async {
    // El router y el contenedor sobreviven al cambio de perfil; el `context` y
    // el `ref` de este widget pueden no hacerlo.
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context, listen: false);

    final outcome =
        await container.read(authNotifierProvider.notifier).switchProfile(null);
    if (outcome != SwitchProfileOutcome.exited &&
        outcome != SwitchProfileOutcome.unchanged) {
      return;
    }

    try {
      final guardian = await container.read(authNotifierProvider.future);
      if (guardian == null) return;
    } catch (_) {
      // Sin sesión del tutor no hay Mi familia a donde ir.
      return;
    }
    router.push(RouteNames.family);
  }

  String _ownBody() {
    final pending = pendingClub;
    if (pending == null) return tr('dashboard.pending_state.body');
    final type = pending.clubTypeName;
    final hasType = type != null && type.isNotEmpty;
    return tr(
      hasType
          ? 'dashboard.pending_state.body_club'
          : 'dashboard.pending_state.body_club_no_type',
      namedArgs: {
        'club': pending.clubName,
        if (hasType) 'type': type,
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final actingName = actingCopyName(ref);
    final acting = actingName != null;
    // Si la ficha firmada ya se subió en el paso 3, no se dice "si aún no la
    // entregas".
    final actingUserId = ref.watch(actingDependentProvider)?.userId;
    final formReceived = actingUserId != null &&
        ref.watch(actingConsentFormUploadedProvider).contains(actingUserId);

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
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
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
                  ? tr(
                      formReceived
                          ? 'dashboard.pending_state.body_acting_form_received'
                          : 'dashboard.pending_state.body_acting',
                      namedArgs: {'name': actingName})
                  : _ownBody(),
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
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
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
