/// Constantes para los nombres y paths de las rutas de la aplicación
class RouteNames {
  RouteNames._();

  // Paths
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String postRegistration = '/post-registration';
  static const String home = '/home';
  static const String dashboard = 'dashboard';
  static const String classes = 'classes';
  static const String activities = 'activities';
  static const String profile = 'profile';
  static const String clubDetail = '/club/:clubId';
  static const String classDetail = '/class/:classId';
  static const String honorDetail = '/honor/:honorId';

  // Paths completos para tabs del home
  static const String homeDashboard = '/home/dashboard';
  static const String homeClasses = '/home/classes';
  static const String homeActivities = '/home/activities';
  static const String homeProfile = '/home/profile';

  // Helpers para paths con parámetros
  static String clubDetailPath(String clubId) => '/club/$clubId';
  static String classDetailPath(String classId) => '/class/$classId';
  static String honorDetailPath(String honorId) => '/honor/$honorId';
}
