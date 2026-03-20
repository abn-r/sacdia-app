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

  // Módulos de acceso rápido (dentro del shell)
  static const String homeMembers = '/home/members';
  static const String homeClub = '/home/club';
  static const String homeEvidences = '/home/evidences';
  static const String homeFinances = '/home/finances';
  static const String homeUnits = '/home/units';
  static const String homeGroupedClass = '/home/grouped-class';
  static const String homeInsurance = '/home/insurance';
  static const String homeInventory = '/home/inventory';
  static const String homeResources = '/home/resources';
  static const String homeCertifications = '/home/certifications';

  // Rutas de detalle fuera del shell
  static const String certificationDetail = '/certification/:certificationId';
  static const String certificationProgress =
      '/certification/:certificationId/progress/:enrollmentId';

  // Investidura
  static const String investiturePendingList = '/investiture/pending';
  static const String investitureHistory =
      '/investiture/enrollment/:enrollmentId/history';

  // Helpers para paths con parámetros
  static String clubDetailPath(String clubId) => '/club/$clubId';
  static String classDetailPath(String classId) => '/class/$classId';
  static String honorDetailPath(String honorId) => '/honor/$honorId';
  static String certificationDetailPath(String certificationId) =>
      '/certification/$certificationId';
  static String certificationProgressPath(
          String certificationId, String enrollmentId) =>
      '/certification/$certificationId/progress/$enrollmentId';
  static String investitureHistoryPath(String enrollmentId) =>
      '/investiture/enrollment/$enrollmentId/history';
}
