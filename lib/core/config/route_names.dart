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
  static const String homeHonors = '/home/honors';
  static const String homeCertifications = '/home/certifications';

  // Información médica del usuario (detalle fuera del shell)
  static const String homeMedicalInfo = '/home/medical-info';

  // Rutas de detalle fuera del shell
  static const String certificationDetail = '/certification/:certificationId';
  static const String certificationProgress =
      '/certification/:certificationId/progress/:enrollmentId';

  // Camporees
  static const String homeCamporees = '/home/camporees';
  static const String camporeeDetail = '/camporee/:camporeeId';
  static const String camporeeMembers = '/camporee/:camporeeId/members';
  static const String camporeeRegisterMember =
      '/camporee/:camporeeId/register';

  // Traslados
  static const String transferRequests = '/transfers';
  static const String transferRequestDetailRoute = '/transfer/:requestId';

  // OAuth callback deep link (io.sacdia.app://auth/callback)
  static const String authCallback = '/auth/callback';

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

  // Camporees helpers
  static String camporeeDetailPath(String camporeeId) =>
      '/camporee/$camporeeId';
  static String camporeeMembersPath(String camporeeId) =>
      '/camporee/$camporeeId/members';
  static String camporeeRegisterMemberPath(String camporeeId) =>
      '/camporee/$camporeeId/register';

  // Traslados helpers
  static String transferRequestDetail(int requestId) =>
      '/transfer/$requestId';

  // Honors evidence & completion
  static const String honorEvidence = '/honor/:honorId/evidence/:userHonorId';
  static const String honorCompletion = '/honor/:honorId/completion/:userHonorId';

  // Helpers
  static String honorEvidencePath(String honorId, String userHonorId) =>
      '/honor/$honorId/evidence/$userHonorId';
  static String honorCompletionPath(String honorId, String userHonorId) =>
      '/honor/$honorId/completion/$userHonorId';

  // Carpetas anuales
  static const String annualFolder = '/annual-folder/:enrollmentId';

  static String annualFolderPath(int enrollmentId) =>
      '/annual-folder/$enrollmentId';

  // Informes mensuales
  static const String monthlyReports = '/monthly-reports/:enrollmentId';
  static const String monthlyReportDetail = '/monthly-report/:reportId';

  static String monthlyReportsPath(int enrollmentId) =>
      '/monthly-reports/$enrollmentId';
  static String monthlyReportDetailPath(int reportId) =>
      '/monthly-report/$reportId';

  // Asignaciones de rol
  static const String roleAssignments = '/role-assignments';

  // Pagos de camporee (miembro)
  static const String camporeePayments =
      '/camporee/:camporeeId/member/:memberId/payments';
  static const String camporeeEnrollClub =
      '/camporee/:camporeeId/enroll-club';

  static String camporeePaymentsPath(int camporeeId, String memberId) =>
      '/camporee/$camporeeId/member/$memberId/payments';
  static String camporeeEnrollClubPath(int camporeeId) =>
      '/camporee/$camporeeId/enroll-club';
}
