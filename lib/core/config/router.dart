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
import 'package:sacdia_app/features/annual_folders/presentation/views/annual_folder_view.dart';
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

import '../../features/auth/domain/entities/authorization_snapshot.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/domain/utils/authorization_utils.dart';
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
import '../../features/classes/presentation/views/classes_list_view.dart';
import '../../features/classes/presentation/sheets/enroll_previous_class_sheet.dart';
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
        final isAlreadyInsideApp = !isPublicRoute &&
            currentPath != RouteNames.splash;

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
                    _fadeThroughBuild(context, state, const ClassesListView()),
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
          final initialHonor = state.extra is Honor ? state.extra as Honor : null;
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

      // Requisitos de honor — checklist de progreso por requisito
      GoRoute(
        path: RouteNames.honorRequirements,
        pageBuilder: (context, state) {
          final honorId =
              int.tryParse(state.pathParameters['honorId']!) ?? 0;
          final userHonorId =
              int.tryParse(state.pathParameters['userHonorId']!) ?? 0;
          final honorName =
              state.uri.queryParameters['name'] ?? 'Requisitos';
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

      // Coordinador: hub principal
      GoRoute(
        path: RouteNames.coordinator,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const CoordinatorHubView(),
        ),
      ),

      // Coordinador: dashboard SLA operativo
      GoRoute(
        path: RouteNames.coordinatorSla,
        pageBuilder: (context, state) => _sharedAxisBuild(
          context,
          state,
          const SLADashboardView(),
        ),
      ),

      // Coordinador: lista de evidencias pendientes
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

      // Coordinador: aprobaciones de camporees
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

  ref.listen<AsyncValue<AppBootstrapState>>(appBootstrapProvider, (_, __) {
    router.refresh();
  });

  return router;
});

// ── Navigation destination data ───────────────────────────────────────────────

class _NavItemConfig {
  /// The shell branch index for this tab. Must match the branch position in
  /// the StatefulShellRoute.indexedStack branches list.
  final int branchIndex;
  final String route;
  final List<List<dynamic>> icon;
  final String label;
  final Set<String> requiredPermissions;

  const _NavItemConfig({
    required this.branchIndex,
    required this.route,
    required this.icon,
    required this.label,
    this.requiredPermissions = const {},
  });
}

const List<_NavItemConfig> _navItemsConfig = [
  _NavItemConfig(
    branchIndex: 0,
    route: RouteNames.homeDashboard,
    icon: HugeIcons.strokeRoundedHome01,
    label: 'Inicio',
  ),
  _NavItemConfig(
    branchIndex: 1,
    route: RouteNames.homeClasses,
    icon: HugeIcons.strokeRoundedSchool,
    label: 'Clases',
    requiredPermissions: {'classes:read'},
  ),
  _NavItemConfig(
    branchIndex: 2,
    route: RouteNames.homeActivities,
    icon: HugeIcons.strokeRoundedCalendar01,
    label: 'Actividades',
    requiredPermissions: {'activities:read'},
  ),
  _NavItemConfig(
    branchIndex: 3,
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
    return hasAnyPermission(user, item.requiredPermissions);
  }).toList();
}

// ── Main shell — adaptive navigation ─────────────────────────────────────────

/// Shell principal con navegación adaptativa:
/// - Phones (< 600dp): Material 3 NavigationBar en la parte inferior.
/// - Tablets / landscape (>= 600dp): NavigationRail a la izquierda.
///
/// Uses [StatefulNavigationShell] so each branch keeps its widget tree alive
/// across tab switches, preventing autoDispose providers from being disposed
/// on every tab change.
///
/// Watches [authNotifierProvider] scoped to the authorization sub-state so
/// the tab list rebuilds reactively when permissions change (e.g. context switch).
class _MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const _MainShell({required this.navigationShell});

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

    // Map the shell's current branch index to the filtered UI position.
    // Quick-access branches (index >= _kNavBranchCount) are not shown in the
    // nav bar, so we fall back to index 0 (Dashboard) for those cases.
    final currentBranchIndex = navigationShell.currentIndex;
    final selectedIndex = () {
      final uiIdx = filteredItems.indexWhere(
        (item) => item.branchIndex == currentBranchIndex,
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
                  navigationShell.goBranch(filteredItems[uiIndex].branchIndex),
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
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    // ── Phone: bottom NavigationBar ──────────────────────────────────────────
    final hasActiveClub =
        authorization?.activeGrant?.sectionId != null;
    final isClassesBranch = currentBranchIndex == 1;

    return Scaffold(
      floatingActionButton: (isClassesBranch && hasActiveClub)
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => const EnrollPreviousClassSheet(),
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Inscribir clase',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (uiIndex) =>
            navigationShell.goBranch(filteredItems[uiIndex].branchIndex),
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
          child: LoadingAnimationWidget.waveDots(
            color: AppColors.primary,
            size: 30,
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
                  'No tienes ninguna clase asignada. Inscríbete en un club para comenzar.',
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
              'Completando inicio de sesión...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
