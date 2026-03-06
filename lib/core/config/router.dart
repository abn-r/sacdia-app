import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/features/activities/presentation/views/activities_list_view.dart';
import 'package:sacdia_app/features/carpeta_evidencias/presentation/views/evidence_folder_view.dart';
import 'package:sacdia_app/features/club/presentation/providers/club_providers.dart';
import 'package:sacdia_app/features/club/presentation/views/club_view.dart';
import 'package:sacdia_app/features/finanzas/presentation/views/finanzas_view.dart';
import 'package:sacdia_app/features/home/presentation/widgets/resources_section.dart';
import 'package:sacdia_app/features/inventario/presentation/views/inventario_view.dart';
import 'package:sacdia_app/features/seguros/presentation/views/seguros_view.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/views/forgot_password_view.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/splash_view.dart';
import '../../features/post_registration/presentation/views/post_registration_shell.dart';
import '../../features/dashboard/presentation/views/dashboard_view.dart';
import '../../features/classes/presentation/views/classes_list_view.dart';
import '../../features/classes/presentation/views/class_detail_with_progress_view.dart';
import '../../features/miembros/presentation/views/miembros_view.dart';
import '../../features/profile/presentation/views/profile_view.dart';
import '../utils/responsive.dart';
import 'route_names.dart';

/// Returns a [CupertinoPage] for use with GoRouter [pageBuilder].
///
/// Unified iOS-style slide-from-right transition on all platforms.
Page<void> _buildPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CupertinoPage<void>(child: child, key: state.pageKey);
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
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
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
      ];

      final isPublicRoute = publicRoutes.contains(currentPath);

      // Mientras el AuthNotifier está resolviendo el estado inicial,
      // quedarse en splash para que no haya redirects prematuros.
      if (isLoading) {
        return currentPath == RouteNames.splash ? null : RouteNames.splash;
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
            _buildPage(context, state, const SplashView()),
      ),

      // Login
      GoRoute(
        path: RouteNames.login,
        pageBuilder: (context, state) =>
            _buildPage(context, state, const LoginView()),
      ),

      // Registro
      GoRoute(
        path: RouteNames.register,
        pageBuilder: (context, state) =>
            _buildPage(context, state, const RegisterView()),
      ),

      // Recuperar contraseña
      GoRoute(
        path: RouteNames.forgotPassword,
        pageBuilder: (context, state) =>
            _buildPage(context, state, const ForgotPasswordView()),
      ),

      // Post-registro
      GoRoute(
        path: RouteNames.postRegistration,
        pageBuilder: (context, state) =>
            _buildPage(context, state, const PostRegistrationShell()),
      ),

      // Shell con navegación adaptativa (bottom bar en phones, rail en tablets)
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.homeDashboard,
            pageBuilder: (context, state) =>
                _buildPage(context, state, const DashboardView()),
          ),
          GoRoute(
            path: RouteNames.homeClasses,
            pageBuilder: (context, state) =>
                _buildPage(context, state, const ClassesListView()),
          ),
          GoRoute(
            path: RouteNames.homeActivities,
            pageBuilder: (context, state) => _buildPage(
              context,
              state,
              const ActivitiesListView(clubId: 1),
            ),
          ),
          GoRoute(
            path: RouteNames.homeProfile,
            pageBuilder: (context, state) =>
                _buildPage(context, state, const ProfileView()),
          ),
          GoRoute(
            path: RouteNames.homeMembers,
            pageBuilder: (context, state) => _buildPage(
              context, state,
              const MiembrosView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeClub,
            pageBuilder: (context, state) => _buildPage(
              context, state,
              const ClubView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeEvidences,
            pageBuilder: (context, state) => _buildPage(
              context, state,
              const _EvidenceFolderShell(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeFinances,
            pageBuilder: (context, state) => _buildPage(
              context, state,
              const FinanzasView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeUnits,
            pageBuilder: (context, state) => _buildPage(
              context, state,
              const _PlaceholderScreen(title: 'Unidades'),
            ),
          ),
          GoRoute(
            path: RouteNames.homeGroupedClass,
            pageBuilder: (context, state) => _buildPage(
              context, state,
              const ClassesListView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeInsurance,
            pageBuilder: (context, state) => _buildPage(
              context, state,
              const SegurosView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeInventory,
            pageBuilder: (context, state) => _buildPage(
              context, state,
              const InventarioView(),
            ),
          ),
          GoRoute(
            path: RouteNames.homeResources,
            pageBuilder: (context, state) => _buildPage(
              context, state,
              const ResourcesSection(),
            ),
          ),
        ],
      ),

      // Detalle de club
      GoRoute(
        path: RouteNames.clubDetail,
        pageBuilder: (context, state) {
          final clubId = state.pathParameters['clubId']!;
          return _buildPage(
              context, state, _PlaceholderScreen(title: 'Club: $clubId'));
        },
      ),

      // Detalle de clase
      GoRoute(
        path: RouteNames.classDetail,
        pageBuilder: (context, state) {
          final classIdStr = state.pathParameters['classId']!;
          final classId = int.tryParse(classIdStr) ?? 0;
          return _buildPage(
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
          final honorId = state.pathParameters['honorId']!;
          return _buildPage(
              context, state, _PlaceholderScreen(title: 'Honor: $honorId'));
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

class _NavItem {
  final String route;
  final List<List<dynamic>> icon;
  final String label;

  const _NavItem({
    required this.route,
    required this.icon,
    required this.label,
  });
}

final List<_NavItem> _navItems = [
  _NavItem(
    route: RouteNames.homeDashboard,
    icon: HugeIcons.strokeRoundedHome01,
    label: 'Inicio',
  ),
  _NavItem(
    route: RouteNames.homeClasses,
    icon: HugeIcons.strokeRoundedSchool,
    label: 'Clases',
  ),
  _NavItem(
    route: RouteNames.homeActivities,
    icon: HugeIcons.strokeRoundedCalendar01,
    label: 'Actividades',
  ),
  _NavItem(
    route: RouteNames.homeProfile,
    icon: HugeIcons.strokeRoundedUser,
    label: 'Perfil',
  ),
];

// ── Main shell — adaptive navigation ─────────────────────────────────────────

/// Shell principal con navegación adaptativa:
/// - Phones (< 600dp): Material 3 NavigationBar en la parte inferior.
/// - Tablets / landscape (>= 600dp): NavigationRail a la izquierda.
class _MainShell extends StatelessWidget {
  final Widget child;

  const _MainShell({required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(RouteNames.homeClasses)) return 1;
    if (location.startsWith(RouteNames.homeActivities)) return 2;
    if (location.startsWith(RouteNames.homeProfile)) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RouteNames.homeDashboard);
      case 1:
        context.go(RouteNames.homeClasses);
      case 2:
        context.go(RouteNames.homeActivities);
      case 3:
        context.go(RouteNames.homeProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _currentIndex(context);
    final useRail = Responsive.isTablet(context);

    if (useRail) {
      // ── Tablet / landscape: side NavigationRail ──────────────────────────
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _navigate(context, index),
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              destinations: _navItems
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
        onDestinationSelected: (index) => _navigate(context, index),
        destinations: _navItems
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

/// Shell que obtiene el clubInstanceId del contexto activo y pasa a [EvidenceFolderView].
///
/// Si el contexto aún no está disponible muestra un loading.
/// Si no hay instancia activa muestra un mensaje de error con instrucción.
class _EvidenceFolderShell extends ConsumerWidget {
  const _EvidenceFolderShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubInstanceAsync = ref.watch(currentClubInstanceProvider);

    return clubInstanceAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
      data: (instance) {
        if (instance == null) {
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
        return EvidenceFolderView(clubInstanceId: instance.id.toString());
      },
    );
  }
}

/// Pantalla placeholder para features aún no implementados
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
