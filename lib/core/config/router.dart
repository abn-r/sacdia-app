import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/features/activities/presentation/views/activities_list_view.dart';
import 'package:sacdia_app/features/certifications/presentation/views/certifications_list_view.dart';
import 'package:sacdia_app/features/certifications/presentation/views/certification_detail_view.dart';
import 'package:sacdia_app/features/certifications/presentation/views/certification_progress_view.dart';
import 'package:sacdia_app/features/investiture/presentation/views/investiture_pending_list_view.dart';
import 'package:sacdia_app/features/investiture/presentation/views/investiture_history_view.dart';
import 'package:sacdia_app/features/evidence_folder/presentation/views/evidence_folder_view.dart';
import 'package:sacdia_app/features/club/presentation/providers/club_providers.dart';
import 'package:sacdia_app/features/club/presentation/views/club_detail_view.dart';
import 'package:sacdia_app/features/club/presentation/views/club_view.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_completion_view.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_detail_view.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_evidence_view.dart';
import 'package:sacdia_app/features/finances/presentation/views/finances_view.dart';
import 'package:sacdia_app/features/home/presentation/widgets/resources_section.dart';
import 'package:sacdia_app/features/inventory/presentation/views/inventory_view.dart';
import 'package:sacdia_app/features/insurance/presentation/views/insurance_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporees_list_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_detail_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_members_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_register_member_view.dart';
import 'package:sacdia_app/features/transfers/presentation/views/transfer_request_detail_view.dart';
import 'package:sacdia_app/features/transfers/presentation/views/transfer_requests_view.dart';
import 'package:sacdia_app/features/units/presentation/views/units_list_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_payments_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_enroll_club_view.dart';
import 'package:sacdia_app/features/annual_folders/presentation/views/annual_folder_view.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/views/monthly_reports_list_view.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/views/monthly_report_detail_view.dart';
import 'package:sacdia_app/features/role_assignments/presentation/views/role_assignments_view.dart';

import '../../features/auth/domain/entities/authorization_snapshot.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/domain/utils/authorization_utils.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../notifications/push_notification_provider.dart';
import '../../features/auth/presentation/views/forgot_password_view.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/splash_view.dart';
import '../../features/post_registration/presentation/views/post_registration_shell.dart';
import '../../features/dashboard/presentation/views/dashboard_view.dart';
import '../../features/classes/presentation/providers/classes_providers.dart';
import '../../features/classes/presentation/views/classes_list_view.dart';
import '../../features/classes/presentation/views/class_detail_with_progress_view.dart';
import '../../features/members/presentation/views/members_view.dart';
import '../../features/profile/presentation/views/profile_view.dart';
import '../../features/profile/presentation/views/medical_info_view.dart';
import '../animations/page_transitions.dart';
import '../utils/responsive.dart';
import 'route_names.dart';

/// Shared-axis slide for standard forward/back navigation.
Page<void> _sharedAxisBuild(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return sharedAxisPage<void>(key: state.pageKey, child: child);
}

/// Cross-fade for bottom-nav tab switching (no directional cue needed).
Page<void> _fadeThroughBuild(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return fadeThroughPage<void>(key: state.pageKey, child: child);
}

/// Slide-up for modal-style pages.
Page<void> _slideUpBuild(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return slideUpPage<void>(key: state.pageKey, child: child);
}

/// Provider principal del router de la aplicación.
///
/// IMPORTANT: The GoRouter instance is created ONCE and kept alive for the
/// entire app lifecycle. Auth state changes are handled via [ref.listen] which
/// calls [router.refresh()] — this triggers a re-evaluation of the redirect
/// callback WITHOUT rebuilding the router itself, avoiding race conditions that
/// stem from constructing a new GoRouter mid-navigation.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: pushNavigatorKey,
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      // Read the current auth state snapshot without watching it here —
      // watching would cause the Provider to rebuild and recreate the router.
      final authState = ref.read(authNotifierProvider);
      final isLoading = authState.isLoading;
      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final currentPath = state.matchedLocation;

      // Rutas públicas que no requieren autenticación
      const publicRoutes = [
        RouteNames.splash,
        RouteNames.login,
        RouteNames.register,
        RouteNames.forgotPassword,
        RouteNames.authCallback,
      ];

      final isPublicRoute = publicRoutes.contains(currentPath);

      // Mientras el AuthNotifier está resolviendo el estado inicial,
      // quedarse en splash para que no haya redirects prematuros.
      // Excepción: /auth/callback debe permanecer para procesar el token OAuth.
      if (isLoading) {
        if (currentPath == RouteNames.splash ||
            currentPath == RouteNames.authCallback) {
          return null;
        }
        return RouteNames.splash;
      }

      // Splash es transitorio: una vez que la carga terminó, siempre salir.
      if (currentPath == RouteNames.splash) {
        if (!isLoggedIn) return RouteNames.login;
        return user.postRegisterComplete
            ? RouteNames.homeDashboard
            : RouteNames.postRegistration;
      }

      // Sin usuario autenticado → login
      if (!isLoggedIn) {
        return isPublicRoute ? null : RouteNames.login;
      }

      // Usuario autenticado en ruta pública → decidir destino
      if (isPublicRoute) {
        return user.postRegisterComplete
            ? RouteNames.homeDashboard
            : RouteNames.postRegistration;
      }

      // Usuario autenticado con post-registro incompleto fuera de la ruta de post-registro
      if (!user.postRegisterComplete &&
          currentPath != RouteNames.postRegistration) {
        return RouteNames.postRegistration;
      }

      // Usuario autenticado con post-registro completo en la ruta de post-registro
      // (e.g., navigated back somehow) → redirigir a home
      if (user.postRegisterComplete &&
          currentPath == RouteNames.postRegistration) {
        return RouteNames.homeDashboard;
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: RouteNames.splash,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const SplashView()),
      ),

      // Login
      GoRoute(
        path: RouteNames.login,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const LoginView()),
      ),

      // Registro
      GoRoute(
        path: RouteNames.register,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const RegisterView()),
      ),

      // Recuperar contraseña
      GoRoute(
        path: RouteNames.forgotPassword,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const ForgotPasswordView()),
      ),

      // Post-registro
      GoRoute(
        path: RouteNames.postRegistration,
        pageBuilder: (context, state) =>
            _slideUpBuild(context, state, const PostRegistrationShell()),
      ),

      // Shell con navegación adaptativa (bottom bar en phones, rail en tablets)
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.homeDashboard,
            pageBuilder: (context, state) =>
                _fadeThroughBuild(context, state, const DashboardView()),
          ),
          GoRoute(
            path: RouteNames.homeClasses,
            pageBuilder: (context, state) =>
                _fadeThroughBuild(context, state, const ClassesListView()),
          ),
          GoRoute(
            path: RouteNames.homeActivities,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context,
              state,
              const ActivitiesListView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeProfile,
            pageBuilder: (context, state) =>
                _fadeThroughBuild(context, state, const ProfileView()),
          ),
          GoRoute(
            path: RouteNames.homeMembers,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context, state,
              const MembersView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeClub,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context, state,
              const ClubView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeEvidences,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context, state,
              const _EvidenceFolderShell(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeFinances,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context, state,
              const FinancesView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeUnits,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context, state,
              const UnitsListView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeGroupedClass,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context, state,
              const _ActiveClassDetailShell(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeInsurance,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context, state,
              const InsuranceView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeInventory,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context, state,
              const InventoryView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeResources,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context, state,
              const ResourcesSection(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeCertifications,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context,
              state,
              const CertificationsListView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeCamporees,
            pageBuilder: (context, state) => _fadeThroughBuild(
              context,
              state,
              const CamporeesListView(),
            ),
          ),
        ],
      ),

      // Información médica del usuario
      GoRoute(
        path: RouteNames.homeMedicalInfo,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const MedicalInfoView()),
      ),

      // Detalle de club
      GoRoute(
        path: RouteNames.clubDetail,
        pageBuilder: (context, state) {
          final clubId = state.pathParameters['clubId']!;
          return _sharedAxisBuild(
              context, state, ClubDetailView(clubId: clubId));
        },
      ),

      // Detalle de clase
      GoRoute(
        path: RouteNames.classDetail,
        pageBuilder: (context, state) {
          final classIdStr = state.pathParameters['classId']!;
          final classId = int.tryParse(classIdStr) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            ClassDetailWithProgressView(classId: classId),
          );
        },
      ),

      // Detalle de honor
      GoRoute(
        path: RouteNames.honorDetail,
        pageBuilder: (context, state) {
          final honorIdStr = state.pathParameters['honorId']!;
          final honorId = int.tryParse(honorIdStr) ?? 0;
          return _sharedAxisBuild(
              context, state, HonorDetailView(honorId: honorId));
        },
      ),

      // Evidencia de honor (especialidad inscripta)
      GoRoute(
        path: RouteNames.honorEvidence,
        pageBuilder: (context, state) {
          final honorId =
              int.tryParse(state.pathParameters['honorId']!) ?? 0;
          final userHonorId =
              int.tryParse(state.pathParameters['userHonorId']!) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            HonorEvidenceView(honorId: honorId, userHonorId: userHonorId),
          );
        },
      ),

      // Celebración de honor completado
      GoRoute(
        path: RouteNames.honorCompletion,
        pageBuilder: (context, state) {
          final honorId =
              int.tryParse(state.pathParameters['honorId']!) ?? 0;
          final userHonorId =
              int.tryParse(state.pathParameters['userHonorId']!) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            HonorCompletionView(honorId: honorId, userHonorId: userHonorId),
          );
        },
      ),

      // Detalle de certificación
      GoRoute(
        path: RouteNames.certificationDetail,
        pageBuilder: (context, state) {
          final certificationIdStr =
              state.pathParameters['certificationId']!;
          final certificationId = int.tryParse(certificationIdStr) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            CertificationDetailView(certificationId: certificationId),
          );
        },
      ),

      // Progreso de certificación
      GoRoute(
        path: RouteNames.certificationProgress,
        pageBuilder: (context, state) {
          final certificationIdStr =
              state.pathParameters['certificationId']!;
          final enrollmentIdStr = state.pathParameters['enrollmentId']!;
          final certificationId = int.tryParse(certificationIdStr) ?? 0;
          final enrollmentId = int.tryParse(enrollmentIdStr) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            CertificationProgressView(
              enrollmentId: enrollmentId,
              certificationId: certificationId,
            ),
          );
        },
      ),

      // Lista de investiduras pendientes (coordinador/admin)
      GoRoute(
        path: RouteNames.investiturePendingList,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const InvestiturePendingListView(),
        ),
      ),

      // Historial de investidura de un enrollment
      GoRoute(
        path: RouteNames.investitureHistory,
        pageBuilder: (context, state) {
          final enrollmentIdStr = state.pathParameters['enrollmentId']!;
          final enrollmentId = int.tryParse(enrollmentIdStr) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            InvestitureHistoryView(enrollmentId: enrollmentId),
          );
        },
      ),

      // Detalle de camporee
      GoRoute(
        path: RouteNames.camporeeDetail,
        pageBuilder: (context, state) {
          final camporeeIdStr = state.pathParameters['camporeeId']!;
          final camporeeId = int.tryParse(camporeeIdStr) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            CamporeeDetailView(camporeeId: camporeeId),
          );
        },
      ),

      // Miembros de un camporee
      GoRoute(
        path: RouteNames.camporeeMembers,
        pageBuilder: (context, state) {
          final camporeeIdStr = state.pathParameters['camporeeId']!;
          final camporeeId = int.tryParse(camporeeIdStr) ?? 0;
          final camporeeName =
              state.uri.queryParameters['name'] ?? 'Camporee';
          return _sharedAxisBuild(
            context,
            state,
            CamporeeMembersView(
              camporeeId: camporeeId,
              camporeeName: camporeeName,
            ),
          );
        },
      ),

      // Lista de solicitudes de traslado
      GoRoute(
        path: RouteNames.transferRequests,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const TransferRequestsView(),
        ),
      ),

      // Detalle de solicitud de traslado
      GoRoute(
        path: RouteNames.transferRequestDetailRoute,
        pageBuilder: (context, state) {
          final requestIdStr = state.pathParameters['requestId']!;
          final requestId = int.tryParse(requestIdStr) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            TransferRequestDetailView(requestId: requestId),
          );
        },
      ),

      // Registrar miembro en camporee
      GoRoute(
        path: RouteNames.camporeeRegisterMember,
        pageBuilder: (context, state) {
          final camporeeIdStr = state.pathParameters['camporeeId']!;
          final camporeeId = int.tryParse(camporeeIdStr) ?? 0;
          return _slideUpBuild(
            context,
            state,
            CamporeeRegisterMemberView(camporeeId: camporeeId),
          );
        },
      ),

      // Pagos de un miembro en un camporee
      GoRoute(
        path: RouteNames.camporeePayments,
        pageBuilder: (context, state) {
          final camporeeId =
              int.tryParse(state.pathParameters['camporeeId']!) ?? 0;
          final memberId = state.pathParameters['memberId']!;
          final memberName = state.uri.queryParameters['name'];
          return _sharedAxisBuild(
            context,
            state,
            CamporeePaymentsView(
              camporeeId: camporeeId,
              memberId: memberId,
              memberName: memberName,
            ),
          );
        },
      ),

      // Inscribir club en camporee
      GoRoute(
        path: RouteNames.camporeeEnrollClub,
        pageBuilder: (context, state) {
          final camporeeId =
              int.tryParse(state.pathParameters['camporeeId']!) ?? 0;
          final camporeeName = state.uri.queryParameters['name'];
          return _sharedAxisBuild(
            context,
            state,
            CamporeeEnrollClubView(
              camporeeId: camporeeId,
              camporeeName: camporeeName,
            ),
          );
        },
      ),

      // Carpeta anual de un enrollment
      GoRoute(
        path: RouteNames.annualFolder,
        pageBuilder: (context, state) {
          final enrollmentId =
              int.tryParse(state.pathParameters['enrollmentId']!) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            AnnualFolderView(enrollmentId: enrollmentId),
          );
        },
      ),

      // Lista de informes mensuales de un enrollment
      GoRoute(
        path: RouteNames.monthlyReports,
        pageBuilder: (context, state) {
          final enrollmentId =
              int.tryParse(state.pathParameters['enrollmentId']!) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            MonthlyReportsListView(enrollmentId: enrollmentId),
          );
        },
      ),

      // Detalle de informe mensual
      GoRoute(
        path: RouteNames.monthlyReportDetail,
        pageBuilder: (context, state) {
          final reportId =
              int.tryParse(state.pathParameters['reportId']!) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            MonthlyReportDetailView(reportId: reportId),
          );
        },
      ),

      // Asignaciones de rol
      GoRoute(
        path: RouteNames.roleAssignments,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const RoleAssignmentsView(),
        ),
      ),

      // OAuth callback deep link — io.sacdia.app://auth/callback?session_token=...&provider=...
      //
      // GoRouter intercepts the deep link automatically because:
      //   - iOS: FlutterDeepLinkingEnabled = true in Info.plist
      //   - Android: intent-filter with scheme io.sacdia.app in AndroidManifest.xml
      //
      // The route extracts session_token and provider from query params, calls
      // AuthNotifier.processOAuthDeepLink, and shows a loading screen while
      // the token exchange with the backend completes. The redirect callback
      // above handles the subsequent navigation once auth state updates.
      GoRoute(
        path: RouteNames.authCallback,
        pageBuilder: (context, state) {
          final sessionToken =
              state.uri.queryParameters['session_token'] ?? '';
          final provider =
              state.uri.queryParameters['provider'] ?? '';
          return _sharedAxisBuild(
            context,
            state,
            _OAuthCallbackScreen(
              sessionToken: sessionToken,
              provider: provider,
            ),
          );
        },
      ),
    ],
  );

  // Listen to auth state changes and refresh the router so the redirect
  // callback re-evaluates with the latest state. This replaces the previous
  // ref.watch() pattern which caused the GoRouter instance to be recreated on
  // every state change, introducing race conditions and double redirects.
  ref.listen<AsyncValue<dynamic>>(authNotifierProvider, (_, __) {
    router.refresh();
  });

  return router;
});

// ── Navigation destination data ───────────────────────────────────────────────

class _NavItemConfig {
  final String route;
  final List<List<dynamic>> icon;
  final String label;
  final Set<String> requiredPermissions;
  final Set<String> legacyRoles;

  const _NavItemConfig({
    required this.route,
    required this.icon,
    required this.label,
    this.requiredPermissions = const {},
    this.legacyRoles = const {},
  });
}

const List<_NavItemConfig> _navItemsConfig = [
  _NavItemConfig(
    route: RouteNames.homeDashboard,
    icon: HugeIcons.strokeRoundedHome01,
    label: 'Inicio',
  ),
  _NavItemConfig(
    route: RouteNames.homeClasses,
    icon: HugeIcons.strokeRoundedSchool,
    label: 'Clases',
    requiredPermissions: {'classes:read'},
    legacyRoles: {'conquistador', 'aventurero', 'guia_mayor'},
  ),
  _NavItemConfig(
    route: RouteNames.homeActivities,
    icon: HugeIcons.strokeRoundedCalendar01,
    label: 'Actividades',
    requiredPermissions: {'activities:read'},
    legacyRoles: {'conquistador', 'aventurero', 'guia_mayor'},
  ),
  _NavItemConfig(
    route: RouteNames.homeProfile,
    icon: HugeIcons.strokeRoundedUser,
    label: 'Perfil',
  ),
];

List<_NavItemConfig> _filterNavItems(
  List<_NavItemConfig> items,
  UserEntity? user,
  AuthorizationSnapshot? authorization,
) {
  if (authorization == null) return items;

  return items.where((item) {
    if (item.requiredPermissions.isEmpty) return true;
    return canByPermissionOrLegacyRole(
      user,
      requiredPermissions: item.requiredPermissions,
      legacyRoles: item.legacyRoles,
    );
  }).toList();
}

int _resolveCurrentIndex(
  BuildContext context,
  List<_NavItemConfig> items,
) {
  final location = GoRouterState.of(context).matchedLocation;
  final idx = items.indexWhere(
    (item) => location.startsWith(item.route),
  );
  return idx.clamp(0, items.length - 1);
}

void _navigateToIndex(
  BuildContext context,
  int index,
  List<_NavItemConfig> items,
) {
  if (index < items.length) {
    context.go(items[index].route);
  }
}

// ── Main shell — adaptive navigation ─────────────────────────────────────────

/// Shell principal con navegación adaptativa:
/// - Phones (< 600dp): Material 3 NavigationBar en la parte inferior.
/// - Tablets / landscape (>= 600dp): NavigationRail a la izquierda.
///
/// Watches [authNotifierProvider] scoped to the authorization sub-state so
/// the tab list rebuilds reactively when permissions change (e.g. context switch).
class _MainShell extends ConsumerWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    final authorization = user?.authorization;

    final filteredItems = _filterNavItems(
      _navItemsConfig,
      user,
      authorization,
    );

    final selectedIndex = _resolveCurrentIndex(context, filteredItems);
    final useRail = Responsive.isTablet(context);

    if (useRail) {
      // ── Tablet / landscape: side NavigationRail ──────────────────────────
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  _navigateToIndex(context, index, filteredItems),
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              destinations: filteredItems
                  .map(
                    (item) => NavigationRailDestination(
                      icon: HugeIcon(
                        icon: item.icon,
                        size: 24,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      selectedIcon: HugeIcon(
                        icon: item.icon,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Phone: bottom NavigationBar ──────────────────────────────────────────
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            _navigateToIndex(context, index, filteredItems),
        destinations: filteredItems
            .map(
              (item) => NavigationDestination(
                icon: HugeIcon(icon: item.icon),
                selectedIcon: HugeIcon(icon: item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Shell que obtiene el clubSectionId del contexto activo y pasa a [EvidenceFolderView].
///
/// Si el contexto aún no está disponible muestra un loading.
/// Si no hay sección activa muestra un mensaje de error con instrucción.
class _EvidenceFolderShell extends ConsumerWidget {
  const _EvidenceFolderShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubSectionAsync = ref.watch(currentClubSectionProvider);

    return clubSectionAsync.when(
      loading: () => Scaffold(
        body: Center(
          child: LoadingAnimationWidget.inkDrop(
            color: AppColors.primary,
            size: 50,
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Carpeta de Evidencias')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No se pudo cargar el contexto del club.\n${e.toString().replaceFirst("Exception: ", "")}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (section) {
        if (section == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Carpeta de Evidencias')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No hay un club activo seleccionado. Por favor selecciona un club desde tu perfil.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return EvidenceFolderView(clubSectionId: section.id.toString());
      },
    );
  }
}

/// Shell que resuelve la clase activa del usuario y pasa su ID a
/// [ClassDetailWithProgressView].
///
/// Sigue el mismo patrón que [_EvidenceFolderShell]: observa un provider
/// asíncrono y muestra loading / error / data según el estado.
///
/// Si el usuario no tiene ninguna clase inscripta muestra un mensaje informativo
/// en lugar de la vista de detalle.
class _ActiveClassDetailShell extends ConsumerWidget {
  const _ActiveClassDetailShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(userClassesProvider);

    return classesAsync.when(
      loading: () => Scaffold(
        body: Center(
          child: LoadingAnimationWidget.stretchedDots(
            color: AppColors.primary,
            size: 50,
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Mi Clase')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No se pudo cargar la clase.\n${e.toString().replaceFirst("Exception: ", "")}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (classes) {
        if (classes.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mi Clase')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No tenés ninguna clase asignada. Inscribite en un club para comenzar.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return ClassDetailWithProgressView(classId: classes.first.id);
      },
    );
  }
}

/// Pantalla de procesamiento del callback OAuth.
///
/// Muestra un loading mientras llama a [AuthNotifier.processOAuthDeepLink].
/// Al completar (éxito o fallo) navega a splash para que el redirect
/// normal tome el control y lleve al usuario a home o login.
///
/// El flujo completo:
///   io.sacdia.app://auth/callback?session_token=xxx&provider=google
///   → GoRouter intercepta → _OAuthCallbackScreen construida con params
///   → llama processOAuthDeepLink → auth state actualizado
///   → router.refresh() llama al redirect → navega a home o login
class _OAuthCallbackScreen extends ConsumerStatefulWidget {
  final String sessionToken;
  final String provider;

  const _OAuthCallbackScreen({
    required this.sessionToken,
    required this.provider,
  });

  @override
  ConsumerState<_OAuthCallbackScreen> createState() =>
      _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends ConsumerState<_OAuthCallbackScreen> {
  static const _tag = 'OAuthCallbackScreen';

  @override
  void initState() {
    super.initState();
    // Diferir la llamada hasta después del primer frame para evitar
    // modificar el árbol de providers durante el build del router.
    WidgetsBinding.instance.addPostFrameCallback((_) => _processCallback());
  }

  Future<void> _processCallback() async {
    const validProviders = ['google', 'apple'];

    if (widget.sessionToken.isEmpty ||
        widget.provider.isEmpty ||
        !validProviders.contains(widget.provider.toLowerCase())) {
      AppLogger.w(
        'OAuth callback recibido con parámetros inválidos — '
        'session_token="${widget.sessionToken.isEmpty ? "(vacío)" : "(presente)"}" '
        'provider="${widget.provider}"',
        tag: _tag,
      );
      // Navegar a login para que el usuario vea el error en contexto.
      if (mounted) context.go(RouteNames.login);
      return;
    }

    AppLogger.i(
      'Procesando OAuth callback — provider: ${widget.provider}',
      tag: _tag,
    );

    await ref.read(authNotifierProvider.notifier).processOAuthDeepLink(
          sessionToken: widget.sessionToken,
          provider: widget.provider,
        );

    // El authNotifierProvider.notifier ya actualiza el estado. El listener
    // en routerProvider llama router.refresh() que ejecuta el redirect.
    // No es necesario navegar manualmente aquí.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingAnimationWidget.inkDrop(
              color: AppColors.primary,
              size: 50,
            ),
            const SizedBox(height: 24),
            Text(
              'Completando inicio de sesión...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
