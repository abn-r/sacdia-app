### Configuración de GoRouter
```dart
// providers/router_provider.dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/',
    refreshListenable: RouterNotifier(ref),
    redirect: (context, state) {
      // Implementar lógica de redirección basada en estado de autenticación
      final isLoggedIn = authState.valueOrNull ?? false;
      final isLoggingIn = state.matchedLocation == '/login';
      
      // Si el usuario no está autenticado y no está en la página de login
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      
      // Si ya está autenticado y está en login, redirigir a home
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }
      
      // En otros casos, no redirigir
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeView(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
      // Añadir más rutas según la aplicación
    ],
  );
});

// Notificador para que GoRouter escuche cambios de autenticación
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  
  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<bool>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }
}
```

### Uso de HugeIcons
```dart
// Ejemplos de uso de HugeIcons
import 'package:hugeicons/hugeicons.dart';

// Uso en widgets
Icon(Huge.home_01_outline, size: 24.0, color: Colors.blue),
Icon(Huge.user_03_outline),
Icon(Huge.notification_01_outline),

// Configuración recomendada de tamaños
final Map<String, double> iconSizes = {
  'xxs': 12.0,
  'xs': 16.0,
  'sm': 20.0,
  'md': 24.0,
  'lg': 32.0,
  'xl': 40.0,
  'xxl': 48.0,
};

// Extensión para theming consistente de iconos
extension IconThemeExtension on BuildContext {
  Icon themedIcon(IconData icon, {double? size, Color? color}) {
    final theme = Theme.of(this);
    return Icon(
      icon,
      size: size ?? 24.0,
      color: color ?? theme.colorScheme.primary,
    );
  }
}
```
