import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/views/forgot_password_view.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/splash_view.dart';
import '../../features/post_registration/presentation/views/post_registration_shell.dart';
import '../../features/dashboard/presentation/views/dashboard_view.dart';
import '../../features/classes/presentation/views/classes_list_view.dart';
import '../../features/profile/presentation/views/profile_view.dart';
import 'route_names.dart';

/// Provider principal del router de la aplicación
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final currentPath = state.matchedLocation;

      // Rutas públicas que no requieren autenticación
      final publicRoutes = [
        RouteNames.splash,
        RouteNames.login,
        RouteNames.register,
        RouteNames.forgotPassword,
      ];

      final isPublicRoute = publicRoutes.contains(currentPath);

      // Mientras carga, mostrar splash
      if (isLoading && currentPath != RouteNames.splash) {
        return RouteNames.splash;
      }

      // Si no está autenticado y está en ruta protegida o en splash -> login
      if (!isLoading && !isLoggedIn && !isPublicRoute) {
        return RouteNames.login;
      }

      // Si no está autenticado y está en splash -> login
      if (!isLoading && !isLoggedIn && currentPath == RouteNames.splash) {
        return RouteNames.login;
      }

      // Si está autenticado y está en splash/login/register -> verificar post-registro
      if (!isLoading && isLoggedIn && isPublicRoute) {
        if (!user.postRegisterComplete) {
          return RouteNames.postRegistration;
        }
        return RouteNames.homeDashboard;
      }

      // Si está autenticado pero post-registro incompleto y NO está en post-registro
      if (!isLoading &&
          isLoggedIn &&
          !user.postRegisterComplete &&
          currentPath != RouteNames.postRegistration) {
        return RouteNames.postRegistration;
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashView(),
      ),

      // Login
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginView(),
      ),

      // Registro
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterView(),
      ),

      // Recuperar contraseña
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordView(),
      ),

      // Post-registro
      GoRoute(
        path: RouteNames.postRegistration,
        builder: (context, state) => const PostRegistrationShell(),
      ),

      // Shell con bottom navigation
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.homeDashboard,
            builder: (context, state) => const DashboardView(),
          ),
          GoRoute(
            path: RouteNames.homeClasses,
            builder: (context, state) => const ClassesListView(),
          ),
          GoRoute(
            path: RouteNames.homeActivities,
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Actividades',
            ),
          ),
          GoRoute(
            path: RouteNames.homeProfile,
            builder: (context, state) => const ProfileView(),
          ),
        ],
      ),

      // Detalle de club
      GoRoute(
        path: RouteNames.clubDetail,
        builder: (context, state) {
          final clubId = state.pathParameters['clubId']!;
          return _PlaceholderScreen(title: 'Club: $clubId');
        },
      ),

      // Detalle de clase
      GoRoute(
        path: RouteNames.classDetail,
        builder: (context, state) {
          final classId = state.pathParameters['classId']!;
          return _PlaceholderScreen(title: 'Clase: $classId');
        },
      ),

      // Detalle de honor
      GoRoute(
        path: RouteNames.honorDetail,
        builder: (context, state) {
          final honorId = state.pathParameters['honorId']!;
          return _PlaceholderScreen(title: 'Honor: $honorId');
        },
      ),
    ],
  );
});

/// Shell principal con bottom navigation bar
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (index) {
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
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Clases',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Actividades',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
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
