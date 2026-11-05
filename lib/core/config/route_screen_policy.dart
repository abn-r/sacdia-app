import 'route_names.dart';

/// Pantallas del catálogo (`screen_catalog.dart`) que tienen ruta en la app,
/// por patrón de ruta (`GoRouterState.fullPath`) → `screenId`.
///
/// El redirect global del router lo consulta como ÚLTIMO paso: si la ruta
/// pedida tiene pantalla y `canViewScreen(subjectFromUser(user), screenId)`
/// es falso, manda a [RouteNames.accessDenied]. Sin `authorization` (estado
/// transitorio) se deja pasar, igual que las pestañas del shell. Los gates por
/// modo de sesión (legal, teléfono vinculado, adolescente, «actuar por»,
/// post-registro, pastor o coordinador sin club) van antes y mandan.
///
/// Las subrutas de una pantalla (historial, detalle, roadmap, pestañas del
/// panel de coordinación, carrito y pedidos de materiales) heredan su gate:
/// no tiene sentido abrir el detalle de lo que no se puede listar.
const Map<String, String> routeScreenIds = {
  // Solo app.
  RouteNames.homeClasses: 'app-classes',
  RouteNames.homeClassesRoadmap: 'app-classes',
  RouteNames.homeClassesCatalog: 'app-classes',
  RouteNames.homeActivities: 'activities',
  RouteNames.coordinator: 'coordinator-hub',
  RouteNames.coordinatorClubs: 'coordinator-hub',
  RouteNames.coordinatorSla: 'coordinator-hub',
  RouteNames.coordinatorReports: 'coordinator-hub',
  RouteNames.coordinatorEvidenceReview: 'coordinator-hub',
  RouteNames.coordinatorEvidenceReviewDetailRoute: 'coordinator-hub',
  RouteNames.homeMembers: 'app-members',
  RouteNames.homeUnits: 'app-units',
  RouteNames.homeClub: 'app-club',
  RouteNames.homeMaterials: 'app-materials',
  RouteNames.materialsProductDetail: 'app-materials',
  RouteNames.materialsCart: 'app-materials',
  RouteNames.materialsSummary: 'app-materials',
  RouteNames.materialsHistory: 'app-materials',
  RouteNames.materialsOrderDetailRoute: 'app-materials',
  RouteNames.materialsOrderPaymentRoute: 'app-materials',
  RouteNames.materialsOrderReceiptRoute: 'app-materials',
  RouteNames.homeGroupedClass: 'app-grouped-class',
  RouteNames.sectionInvestiture: 'app-section-investiture',
  RouteNames.sectionInvestitureHistory: 'app-section-investiture',
  RouteNames.investitureAuthorize: 'app-investiture-authorizer',
  RouteNames.investitureAuthorizeDetail: 'app-investiture-authorizer',
  // Doble superficie (admin + app) con ruta en la app.
  RouteNames.homeEvidences: 'clubs-evidence-folders-list',
  RouteNames.homeFinances: 'finances',
  RouteNames.homeInsurance: 'insurance-by-section',
  RouteNames.homeInventory: 'club-inventory',
  RouteNames.homeResources: 'resources-list',
  RouteNames.homeReports: 'reports-list',
  RouteNames.homeCamporees: 'campamentos-list-local',
  RouteNames.homeClubRankings: 'annual-folders-rankings',
};

/// `screenId` del catálogo para el patrón de ruta [fullPath], o `null` si la
/// ruta no está gobernada por el catálogo.
String? screenIdForRoute(String? fullPath) {
  if (fullPath == null || fullPath.isEmpty) return null;
  final normalized = fullPath.length > 1 && fullPath.endsWith('/')
      ? fullPath.substring(0, fullPath.length - 1)
      : fullPath;
  return routeScreenIds[normalized];
}
