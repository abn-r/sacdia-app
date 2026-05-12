import 'package:easy_localization/easy_localization.dart';
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
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_completion_view.dart';
import 'package:sacdia_app/features/honors/presentation/views/honors_catalog_view.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_detail_view.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_evidence_view.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_requirements_view.dart';
import 'package:sacdia_app/features/finances/presentation/views/finances_view.dart';
import 'package:sacdia_app/features/resources/presentation/views/resources_view.dart';
import 'package:sacdia_app/features/inventory/presentation/views/inventory_view.dart';
import 'package:sacdia_app/features/insurance/presentation/views/insurance_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporees_list_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_detail_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_members_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_register_member_view.dart';
import 'package:sacdia_app/features/transfers/presentation/views/transfer_request_detail_view.dart';
import 'package:sacdia_app/features/transfers/presentation/views/transfer_requests_view.dart';
import 'package:sacdia_app/features/units/presentation/views/member_of_month_history_view.dart';
import 'package:sacdia_app/features/units/presentation/views/units_list_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_payments_view.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_enroll_club_view.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/views/monthly_reports_list_view.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/views/monthly_report_detail_view.dart';
import 'package:sacdia_app/features/role_assignments/presentation/views/role_assignments_view.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_hub_view.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/sla_dashboard_view.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/evidence_review_list_view.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/evidence_review_detail_view.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/camporee_approvals_view.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/notifications/presentation/views/notifications_inbox_view.dart';
import 'package:sacdia_app/features/achievements/presentation/views/achievements_view.dart';
import 'package:sacdia_app/features/support/presentation/views/support_view.dart';
import 'package:sacdia_app/features/support/presentation/views/faq_view.dart';
import 'package:sacdia_app/features/support/presentation/views/contact_view.dart';
import 'package:sacdia_app/features/support/presentation/views/report_problem_view.dart';
import 'package:sacdia_app/features/rankings/presentation/screens/member_breakdown_screen.dart';
import 'package:sacdia_app/features/rankings/presentation/screens/my_ranking_screen.dart';
import 'package:sacdia_app/features/rankings/presentation/screens/section_ranking_screen.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../providers/app_bootstrap_provider.dart';
import '../notifications/push_notification_provider.dart';
import '../../features/auth/presentation/views/forgot_password_view.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/splash_view.dart';
import '../../features/post_registration/presentation/views/post_registration_shell.dart';
import '../../features/dashboard/presentation/views/dashboard_view.dart';
import '../../features/classes/presentation/providers/classes_providers.dart';
import '../../features/classes/presentation/views/classes_tabs_view.dart';
import '../../features/classes/presentation/views/class_detail_with_progress_view.dart';
import '../../features/classes/presentation/views/roadmap_full_screen_view.dart';
import '../../features/members/presentation/views/members_view.dart';
import '../../features/profile/presentation/views/profile_view.dart';
import '../../features/profile/presentation/views/medical_info_view.dart';
import '../animations/page_transitions.dart';
import '../utils/responsive.dart';
import '../persona/index.dart';
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
      final bootstrapAsync = ref.read(appBootstrapProvider);

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

      // ── Bootstrap gate (authenticated users only) ──
      if (isLoggedIn) {
        final isBootstrapLoading = bootstrapAsync.isLoading;
        final bootstrapValue = bootstrapAsync.valueOrNull;

        // Whether the user is already inside the authenticated shell (any
        // /home/* route or post-registration). In this case, do NOT redirect
        // to splash while bootstrap re-validates — doing so causes GoRouter to
        // unmount and immediately remount the StatefulShellRoute in the same
        // frame, which triggers a Duplicate GlobalKey crash.
        // This scenario occurs during a context switch: switchContext() updates
        // authNotifierProvider → AppBootstrapNotifier invalidates itself →
        // bootstrap briefly enters AsyncLoading → router refreshes.
        // Staying put (return null) is safe: the bootstrap will resolve quickly
        // and fire another router.refresh() that re-evaluates correctly.
        final isAlreadyInsideApp =
            !isPublicRoute && currentPath != RouteNames.splash;

        // Still validating permissions → stay on splash (first boot only)
        if (isBootstrapLoading) {
          if (currentPath == RouteNames.splash) return null;
          // User already inside the app (e.g., mid-session context switch) →
          // stay on the current route while bootstrap re-validates silently.
          if (isAlreadyInsideApp) return null;
          return RouteNames.splash;
        }

        // Unexpected error → stay on splash (shows retry UI)
        if (bootstrapAsync.hasError) {
          if (currentPath == RouteNames.splash) return null;
          return RouteNames.splash;
        }

        // Retry UI shown → stay on splash
        if (bootstrapValue is AppBootstrapError) {
          if (currentPath == RouteNames.splash) return null;
          return RouteNames.splash;
        }

        // Nuclear reset happened → go to login
        if (bootstrapValue is AppBootstrapUnauthenticated) {
          return RouteNames.login;
        }

        // AppBootstrapReady → fall through to normal routing
      }

      // Splash es transitorio: una vez que la carga terminó, siempre salir.
      // T-15 / T-17: landing redirect only fires from splash (post-login entry).
      // Any other path (deep link, mid-session navigation) falls through
      // untouched — this satisfies FR-4 (no re-trigger on context switch) and
      // FR-6 / R5 (deep-link target preserved: GoRouter evaluates the redirect
      // with state.matchedLocation == the final intended path, NOT the transient
      // splash, so deep links never hit this block).
      if (currentPath == RouteNames.splash) {
        if (!isLoggedIn) return RouteNames.login;
        if (!user.postRegisterComplete) return RouteNames.postRegistration;
        final persona = resolvePersona(user.authorization);
        return personaLandingRoute(persona);
      }

      // Sin usuario autenticado → login
      if (!isLoggedIn) {
        return isPublicRoute ? null : RouteNames.login;
      }

      // T-16: Usuario autenticado en ruta pública → decidir destino
      // Uses persona-routed landing for consistency with post-login flow.
      if (isPublicRoute) {
        if (!user.postRegisterComplete) return RouteNames.postRegistration;
        final persona = resolvePersona(user.authorization);
        return personaLandingRoute(persona);
      }

      // Usuario autenticado con post-registro incompleto fuera de la ruta de post-registro
      if (!user.postRegisterComplete &&
          currentPath != RouteNames.postRegistration) {
        return RouteNames.postRegistration;
      }

      // T-16: Usuario autenticado con post-registro completo en la ruta de post-registro
      // (e.g., navigated back somehow) → redirigir al destino de la persona.
      if (user.postRegisterComplete &&
          currentPath == RouteNames.postRegistration) {
        final persona = resolvePersona(user.authorization);
        return personaLandingRoute(persona);
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

      // Shell con navegación adaptativa (bottom bar en phones, rail en tablets).
      //
      // StatefulShellRoute.indexedStack preserves the widget tree of every
      // branch across tab switches, so autoDispose providers are NOT disposed
      // when the user switches tabs. Each StatefulShellBranch gets its own
      // Navigator stack that survives as long as the shell is alive.
      //
      // The four primary nav-bar tabs are modelled as individual branches.
      // The remaining /home/* "quick-access" modules each get their own branch
      // too — they are not shown in the nav bar but still benefit from the
      // preserved widget tree when navigated to via context.go().
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _MainShell(navigationShell: navigationShell),
        branches: [
          // ── Branch 0: Dashboard ──────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeDashboard,
                pageBuilder: (context, state) =>
                    _fadeThroughBuild(context, state, const DashboardView()),
              ),
            ],
          ),

          // ── Branch 1: Clases ─────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeClasses,
                pageBuilder: (context, state) =>
                    _fadeThroughBuild(context, state, const ClassesTabsView()),
                routes: [
                  // Roadmap como pantalla completa con AppBar y botón back.
                  // Accesible via context.push(RouteNames.homeClassesRoadmap).
                  GoRoute(
                    path: 'roadmap',
                    pageBuilder: (context, state) => _sharedAxisBuild(
                      context,
                      state,
                      const RoadmapFullScreenView(),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Branch 2: Actividades ────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeActivities,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const ActivitiesListView(),
                ),
              ),
            ],
          ),

          // ── Branch 3: Perfil ─────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeProfile,
                pageBuilder: (context, state) =>
                    _fadeThroughBuild(context, state, const ProfileView()),
              ),
            ],
          ),

          // ── Branch 4: Miembros (quick-access, no nav bar) ────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeMembers,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const MembersView(),
                ),
              ),
            ],
          ),

          // ── Branch 5: Club (quick-access, no nav bar) ────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeClub,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const ClubView(),
                ),
              ),
            ],
          ),

          // ── Branch 6: Carpeta de evidencias (quick-access, no nav bar) ───
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeEvidences,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const _EvidenceFolderShell(),
                ),
              ),
            ],
          ),

          // ── Branch 7: Finanzas (quick-access, no nav bar) ────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeFinances,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const FinancesView(),
                ),
              ),
            ],
          ),

          // ── Branch 8: Unidades (quick-access, no nav bar) ────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeUnits,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const UnitsListView(),
                ),
              ),
            ],
          ),

          // ── Branch 9: Clase agrupada (quick-access, no nav bar) ──────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeGroupedClass,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const _ActiveClassDetailShell(),
                ),
              ),
            ],
          ),

          // ── Branch 10: Seguro (quick-access, no nav bar) ─────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeInsurance,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const InsuranceView(),
                ),
              ),
            ],
          ),

          // ── Branch 11: Inventario (quick-access, no nav bar) ─────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeInventory,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const InventoryView(),
                ),
              ),
            ],
          ),

          // ── Branch 12: Recursos (quick-access, no nav bar) ───────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeResources,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const ResourcesView(),
                ),
              ),
            ],
          ),

          // ── Branch 13: Honores (quick-access, no nav bar) ────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeHonors,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const HonorsCatalogView(),
                ),
              ),
            ],
          ),

          // ── Branch 14: Certificaciones (quick-access, no nav bar) ────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeCertifications,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const CertificationsListView(),
                ),
              ),
            ],
          ),

          // ── Branch 15: Camporees (quick-access, no nav bar) ──────────────
          StatefulShellBranch(
            routes: [
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

          // ── Branch 16: Logros / Achievements (quick-access, no nav bar) ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeAchievements,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const AchievementsView(),
                ),
              ),
            ],
          ),

          // ── Branch 17: Mi Ranking (quick-access, no nav bar) ─────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homeMyRanking,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const MyRankingScreen(),
                ),
              ),
            ],
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
      // The caller may pass the already-loaded Honor object as state.extra
      // to avoid re-fetching the full catalog on every open.
      GoRoute(
        path: RouteNames.honorDetail,
        pageBuilder: (context, state) {
          final honorIdStr = state.pathParameters['honorId']!;
          final honorId = int.tryParse(honorIdStr) ?? 0;
          final initialHonor =
              state.extra is Honor ? state.extra as Honor : null;
          return _sharedAxisBuild(
            context,
            state,
            HonorDetailView(honorId: honorId, initialHonor: initialHonor),
          );
        },
      ),

      // Evidencia de honor (especialidad inscrita)
      GoRoute(
        path: RouteNames.honorEvidence,
        pageBuilder: (context, state) {
          final honorId = int.tryParse(state.pathParameters['honorId']!) ?? 0;
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
          final honorId = int.tryParse(state.pathParameters['honorId']!) ?? 0;
          final userHonorId =
              int.tryParse(state.pathParameters['userHonorId']!) ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            HonorCompletionView(honorId: honorId, userHonorId: userHonorId),
          );
        },
      ),

      // Requisitos de honor — checklist de progreso por requisito
      GoRoute(
        path: RouteNames.honorRequirements,
        pageBuilder: (context, state) {
          final honorId = int.tryParse(state.pathParameters['honorId']!) ?? 0;
          final userHonorId =
              int.tryParse(state.pathParameters['userHonorId']!) ?? 0;
          final honorName = state.uri.queryParameters['name'] ??
              tr('router.honor_requirements.default_title');
          return _sharedAxisBuild(
            context,
            state,
            HonorRequirementsView(
              honorId: honorId,
              userHonorId: userHonorId,
              honorName: honorName,
            ),
          );
        },
      ),

      // Detalle de certificación
      GoRoute(
        path: RouteNames.certificationDetail,
        pageBuilder: (context, state) {
          final certificationIdStr = state.pathParameters['certificationId']!;
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
          final certificationIdStr = state.pathParameters['certificationId']!;
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
          final camporeeName = state.uri.queryParameters['name'] ??
              tr('router.camporee_members.default_name');
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

      // Compat legacy: la carpeta anual ahora usa el flujo canónico por sección
      // activa en EvidenceFolderView. El enrollment en el path se conserva sólo
      // para no romper deep links antiguos.
      GoRoute(
        path: RouteNames.annualFolder,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const _EvidenceFolderShell()),
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
          final reportId = int.tryParse(state.pathParameters['reportId']!) ?? 0;
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

      // ── Coordinator shell — separate StatefulShellRoute (PR-4) ─────────────
      //
      // Coordinator-persona users are routed to this shell exclusively.
      // It maintains its own 5 branches (indices 0–4) scoped independently of
      // the main shell's branches (0–17), satisfying design R2 mitigation.
      //
      // Context-switch from coordinator → club re-mounts main shell: the
      // router.refresh() listener on authNotifierProvider re-evaluates the
      // redirect, resolvePersona() returns a non-coordinator persona, and
      // personaLandingRoute() redirects to the main shell's landing route.
      // No explicit guard needed here — the redirect logic handles it (FR-5,
      // S-15).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _CoordinatorShell(navigationShell: navigationShell),
        branches: [
          // ── Coordinator Branch 0: Hub ──────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.coordinator,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const CoordinatorHubView(),
                ),
              ),
            ],
          ),

          // ── Coordinator Branch 1: Clubes / Aprobaciones ───────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.coordinatorClubs,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const CamporeeApprovalsView(),
                ),
              ),
            ],
          ),

          // ── Coordinator Branch 2: Reportes / SLA ──────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.coordinatorReports,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const SLADashboardView(),
                ),
              ),
            ],
          ),

          // ── Coordinator Branch 3: Actividades ─────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.coordinatorActivities,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const ActivitiesListView(),
                ),
              ),
            ],
          ),

          // ── Coordinator Branch 4: Perfil ───────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.coordinatorProfile,
                pageBuilder: (context, state) => _fadeThroughBuild(
                  context,
                  state,
                  const ProfileView(),
                ),
              ),
            ],
          ),
        ],
      ),

      // Coordinador: dashboard SLA operativo (deep-link / sub-view entry)
      GoRoute(
        path: RouteNames.coordinatorSla,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const SLADashboardView(),
        ),
      ),

      // Coordinador: lista de evidencias pendientes (deep-link / sub-view entry)
      GoRoute(
        path: RouteNames.coordinatorEvidenceReview,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const EvidenceReviewListView(),
        ),
      ),

      // Coordinador: detalle de evidencia
      GoRoute(
        path: RouteNames.coordinatorEvidenceReviewDetailRoute,
        pageBuilder: (context, state) {
          final typeStr = state.pathParameters['type'] ?? 'folder';
          final id = state.pathParameters['id'] ?? '';
          final type = EvidenceReviewType.fromString(typeStr);
          return _sharedAxisBuild(
            context,
            state,
            EvidenceReviewDetailView(type: type, id: id),
          );
        },
      ),

      // Coordinador: aprobaciones de camporees (deep-link / sub-view entry)
      GoRoute(
        path: RouteNames.coordinatorCamporeeApprovals,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const CamporeeApprovalsView(),
        ),
      ),

      // Bandeja de notificaciones
      GoRoute(
        path: RouteNames.notificationsInbox,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const NotificationsInboxView(),
        ),
      ),

      // Miembro del Mes — Historial
      GoRoute(
        path: RouteNames.memberOfMonthHistory,
        pageBuilder: (context, state) {
          final clubId =
              int.tryParse(state.pathParameters['clubId'] ?? '') ?? 0;
          final sectionId =
              int.tryParse(state.pathParameters['sectionId'] ?? '') ?? 0;
          return _sharedAxisBuild(
            context,
            state,
            MemberOfMonthHistoryView(
              clubId: clubId,
              sectionId: sectionId,
            ),
          );
        },
      ),

      // Detalle de logro (deep-link desde notificación push)
      // Opens the achievements list; the UI can scroll to the specific item.
      GoRoute(
        path: RouteNames.achievementDetail,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const AchievementsView(),
        ),
      ),

      // Ranking de sección — drill-down fuera del shell (push).
      // Recibe el sectionId como path param para evitar dependencia de contexto.
      GoRoute(
        path: RouteNames.sectionRanking,
        pageBuilder: (context, state) {
          final sectionIdStr = state.pathParameters['sectionId'];
          final sectionId = int.tryParse(sectionIdStr ?? '');
          if (sectionId == null) {
            return _sharedAxisBuild(
              context,
              state,
              const Scaffold(
                body: Center(child: Text('Sección inválida')),
              ),
            );
          }
          return _sharedAxisBuild(
            context,
            state,
            SectionRankingScreen(sectionId: sectionId),
          );
        },
      ),

      // Desglose de puntaje de un miembro — drill-down desde MyRankingScreen o
      // SectionRankingScreen. Recibe enrollmentId como path param e yearId como
      // query param para construir el request sin dependencia de contexto.
      GoRoute(
        path: RouteNames.memberBreakdown,
        pageBuilder: (context, state) {
          final enrollmentIdStr = state.pathParameters['enrollmentId'];
          final yearIdStr = state.uri.queryParameters['year_id'];
          final enrollmentId = int.tryParse(enrollmentIdStr ?? '');
          final yearId = int.tryParse(yearIdStr ?? '');
          if (enrollmentId == null || yearId == null) {
            return _sharedAxisBuild(
              context,
              state,
              const Scaffold(
                body: Center(child: Text('Parámetros de desglose inválidos')),
              ),
            );
          }
          return _sharedAxisBuild(
            context,
            state,
            MemberBreakdownScreen(
              enrollmentId: enrollmentId,
              yearId: yearId,
            ),
          );
        },
      ),

      // Soporte / Ayuda — hub principal
      GoRoute(
        path: SupportView.routeName,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const SupportView()),
      ),

      // Soporte — FAQ
      GoRoute(
        path: FaqView.routeName,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const FaqView()),
      ),

      // Soporte — Contacto
      GoRoute(
        path: ContactView.routeName,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const ContactView()),
      ),

      // Soporte — Reportar problema
      GoRoute(
        path: ReportProblemView.routeName,
        pageBuilder: (context, state) =>
            _sharedAxisBuild(context, state, const ReportProblemView()),
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
          final sessionToken = state.uri.queryParameters['session_token'] ?? '';
          final provider = state.uri.queryParameters['provider'] ?? '';
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

  ref.listen<AsyncValue<AppBootstrapState>>(appBootstrapProvider, (_, __) {
    router.refresh();
  });

  return router;
});

// ── Navigation destination data ───────────────────────────────────────────────
//
// MIGRATED (PR-2): _NavItemConfig, _navItemsConfig, and _filterNavItems have
// been replaced by the persona module. Nav slot configuration now lives in
// lib/core/persona/persona_nav_config.dart and is consumed via
// personaNavSlotsProvider (see _MainShell below).
//
// Slot definitions per persona:
//   Miembro     → Dashboard | Clases | Actividades | Ranking  | Perfil
//   Consejero   → Mi Unidad | Clases | Miembros    | Actividades | Perfil
//   Director    → Miembros  | Club   | Finanzas    | Actividades | Perfil
//   Tesorero    → Finanzas  | Seguros| Club        | Actividades | Perfil
//   Coordinador → Hub       | Clubes | Reportes    | Actividades | Perfil  (PR-4 shell)
//
// All 18 StatefulShellBranch indices (0–17) are preserved unchanged (NFR-5).

// ── Main shell — adaptive navigation ─────────────────────────────────────────

/// Shell principal con navegación adaptativa:
/// - Phones (< 600dp): Material 3 NavigationBar en la parte inferior.
/// - Tablets / landscape (>= 600dp): NavigationRail a la izquierda.
///
/// Uses [StatefulNavigationShell] so each branch keeps its widget tree alive
/// across tab switches, preventing autoDispose providers from being disposed
/// on every tab change.
///
/// Watches [personaNavSlotsProvider] which derives the [NavSlot] list from the
/// current [Persona]. Rebuilds only when the persona changes (e.g. after login
/// or a context switch via [activeAssignmentId]).
///
/// [NavBadge] is applied to each slot icon when [NavSlot.badgeSource] is not
/// [NavBadgeSource.none], rendering unread notification counts inline.
class _MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const _MainShell({required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(personaNavSlotsProvider);

    // Defensive guard (PR-4): coordinator persona should never reach _MainShell
    // because the post-login redirect sends coordinators to /coordinator which
    // mounts _CoordinatorShell instead. If somehow a coordinator ends up here
    // (e.g., a direct context.go() call to a main-shell route), we render the
    // standard shell with the coordinator's slots — this is safe because
    // personaNavSlotsProvider already returns the coordinator config with
    // branchIndex 0–4 scoped to the coordinator shell. The coordinator shell's
    // redirect (router.refresh → personaLandingRoute → /coordinator) will
    // correct the navigation in the next frame.

    // Map the shell's current branch index to the persona-slot UI position.
    // Branches that are not part of the current persona's nav (quick-access or
    // other-persona slots) are not shown; we fall back to index 0 in that case.
    final currentBranchIndex = navigationShell.currentIndex;
    final selectedIndex = () {
      final uiIdx = slots.indexWhere(
        (slot) => slot.branchIndex == currentBranchIndex,
      );
      return uiIdx < 0 ? 0 : uiIdx;
    }();

    final useRail = Responsive.isTablet(context);

    if (useRail) {
      // ── Tablet / landscape: side NavigationRail ──────────────────────────
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (uiIndex) =>
                  navigationShell.goBranch(slots[uiIndex].branchIndex),
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              destinations: slots
                  .map(
                    (slot) => NavigationRailDestination(
                      icon: NavBadge(
                        source: slot.badgeSource,
                        child: HugeIcon(
                          icon: slot.icon,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      selectedIcon: NavBadge(
                        source: slot.badgeSource,
                        child: HugeIcon(
                          icon: slot.icon,
                          size: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      label: Semantics(
                        label: tr(slot.labelKey),
                        child: Text(tr(slot.labelKey)),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    // ── Phone: bottom NavigationBar ──────────────────────────────────────────
    // El FAB de "Inscribir clase" fue movido a ClassesListView para evitar
    // que se filtre al detalle de clase durante Navigator.push (branch 1 sigue
    // activo y el Scaffold del shell lo heredaba).
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (uiIndex) =>
            navigationShell.goBranch(slots[uiIndex].branchIndex),
        // Each destination is wrapped in Semantics to explicitly declare the
        // Spanish label and button role, mirroring the NavigationRail label
        // pattern for screen-reader parity (PR-2 a11y WARNING fix).
        destinations: slots
            .map(
              (slot) => Semantics(
                label: tr(slot.labelKey),
                button: true,
                child: NavigationDestination(
                  icon: NavBadge(
                    source: slot.badgeSource,
                    child: HugeIcon(icon: slot.icon),
                  ),
                  selectedIcon: NavBadge(
                    source: slot.badgeSource,
                    child: HugeIcon(icon: slot.icon),
                  ),
                  label: tr(slot.labelKey),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Coordinator shell ─────────────────────────────────────────────────────────

/// Coordinator-persona navigation shell.
///
/// A dedicated [StatefulShellRoute.indexedStack]-driven shell for the
/// coordinator persona. Lives outside the main club shell so coordinator
/// screens (global-scope, no clubId required) never mix with club-scoped
/// providers (design §4 — separate StatefulShellRoute decision).
///
/// Branches (0–4, scoped independently of main shell's 0–17):
///   0 → Hub          (/coordinator)
///   1 → Clubes       (/coordinator/clubs)
///   2 → Reportes     (/coordinator/reports)
///   3 → Actividades  (/coordinator/coord-activities)
///   4 → Perfil       (/coordinator/coord-profile)
///
/// Context-switch to a club persona: the router.refresh() listener causes
/// redirect to re-evaluate; resolvePersona() returns a non-coordinator
/// persona and personaLandingRoute() sends the user to the main shell.
/// No crash — GoRouter simply unmounts this shell and mounts the main one.
class _CoordinatorShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const _CoordinatorShell({required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Coordinator slot config (branchIndex 0–4, scoped to this shell).
    final slots = personaNavConfig[Persona.coordinador]!;

    final currentBranchIndex = navigationShell.currentIndex;
    final selectedIndex = () {
      final uiIdx = slots.indexWhere(
        (slot) => slot.branchIndex == currentBranchIndex,
      );
      return uiIdx < 0 ? 0 : uiIdx;
    }();

    final useRail = Responsive.isTablet(context);

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (uiIndex) =>
                  navigationShell.goBranch(slots[uiIndex].branchIndex),
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              destinations: slots
                  .map(
                    (slot) => NavigationRailDestination(
                      icon: NavBadge(
                        source: slot.badgeSource,
                        child: HugeIcon(
                          icon: slot.icon,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      selectedIcon: NavBadge(
                        source: slot.badgeSource,
                        child: HugeIcon(
                          icon: slot.icon,
                          size: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      label: Semantics(
                        label: tr(slot.labelKey),
                        child: Text(tr(slot.labelKey)),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (uiIndex) =>
            navigationShell.goBranch(slots[uiIndex].branchIndex),
        destinations: slots
            .map(
              (slot) => NavigationDestination(
                icon: NavBadge(
                  source: slot.badgeSource,
                  child: HugeIcon(icon: slot.icon),
                ),
                selectedIcon: NavBadge(
                  source: slot.badgeSource,
                  child: HugeIcon(icon: slot.icon),
                ),
                label: tr(slot.labelKey),
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
          child: LoadingAnimationWidget.waveDots(
            color: AppColors.primary,
            size: 30,
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(tr('router.evidence_folder.title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              tr('router.evidence_folder.context_error', namedArgs: {
                'error': e.toString().replaceFirst('Exception: ', ''),
              }),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (section) {
        if (section == null) {
          return Scaffold(
            appBar: AppBar(title: Text(tr('router.evidence_folder.title'))),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  tr('router.evidence_folder.no_active_club'),
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
/// Si el usuario no tiene ninguna clase inscrita muestra un mensaje informativo
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
        appBar: AppBar(title: Text(tr('router.active_class.title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              tr('router.active_class.load_error', namedArgs: {
                'error': e.toString().replaceFirst('Exception: ', ''),
              }),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (classes) {
        if (classes.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(tr('router.active_class.title'))),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  tr('router.active_class.no_class_assigned'),
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
            LoadingAnimationWidget.waveDots(
              color: AppColors.primary,
              size: 30,
            ),
            const SizedBox(height: 24),
            Text(
              tr('router.oauth_callback.completing_signin'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
